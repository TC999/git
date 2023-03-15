/*
 * GIT - the stupid content tracker
 *
 * Copyright (c) Jiang Xin, 2023
 */
#include "builtin.h"
#include "config.h"
#include "object-store.h"
#include "pathspec.h"
#include "parse-options.h"
#include "tree.h"

enum walk_tree_flags {
	MARK_TREE_DIRTY = (1 << 0),
};

/*
 * file_entry is a linked list, which is used to store
 * direct file entries inside a tree.
 */
struct file_entry {
	char *name;
	unsigned int mode;
	struct object_id oid;
	struct file_entry *next;
};

/*
 * lazy_tree is a linked list if next is not null. We will
 * store direct subtree in the dir_entry field.
 */
struct lazy_tree {
	char *name;
	struct tree tree;
	unsigned int loaded : 1, dirty : 1;

	/* children files adn dirs */
	struct lazy_tree *dir_entry;
	struct file_entry *file_entry;

	/* sibling dirs */
	struct lazy_tree *next;
};

/*
 * entries is an array of treeent, to store entries in a tree,
 * and will be used to rehash the tree.
 */
static struct treeent {
	char *name;
	int len;
	struct object_id *oid;
	unsigned mode;
} **entries;

/* alloc is the number of treeent already allocated by calling ALLOC_GROW. */
static int alloc;

static const char *edit_tree_usage[] = {
	"git edit-tree [-z] [-f <input-file>] <tree-id>", NULL
};

static void free_one_file_entry(struct file_entry *head)
{
	if (head) {
		free(head->name);
		free(head);
	}
}

static void free_file_entry_list(struct file_entry *head)
{
	struct file_entry *tmp;
	while (head) {
		tmp = head;
		head = head->next;
		free_one_file_entry(tmp);
	}
}

static void free_tree_entry_list(struct lazy_tree *head);

static void free_one_tree_entry(struct lazy_tree *head)
{
	if (head) {
		free(head->name);
		free_tree_buffer(&head->tree);
		free_file_entry_list(head->file_entry);
		head->file_entry = NULL;
		free_tree_entry_list(head->dir_entry);
		head->dir_entry = NULL;
		free(head);
	}
}

static void free_tree_entry_list(struct lazy_tree *head)
{
	struct lazy_tree *tmp;
	while (head) {
		tmp = head;
		head = head->next;
		free_one_tree_entry(tmp);
	}
}

static struct lazy_tree *new_lazy_tree(const char *name,
				       const struct object_id *oid, int parse)
{
	struct lazy_tree *tree;

	tree = xcalloc(1, sizeof(*tree));
	tree->name = xstrdup(name);
	tree->dirty = 0;
	if (oid) {
		tree->tree.object.oid = *oid;
		if (parse)
			parse_tree_gently(&tree->tree, 1);
	}
	return tree;
}

static int is_place_holder_tree(struct lazy_tree *tree)
{
	if (is_null_oid(&tree->tree.object.oid))
		return 1;
	return 0;
}

static int fill_tree_entry(const struct object_id *oid, struct strbuf *base,
			   const char *pathname, unsigned mode, void *context)
{
	struct lazy_tree *tree = context;
	enum object_type type = object_type(mode);

	if (type == OBJ_TREE) {
		struct lazy_tree **last;
		for (last = &tree->dir_entry; *last; last = &(*last)->next)
			;
		*last = new_lazy_tree(pathname, oid, 1);
	} else {
		struct file_entry **last;
		for (last = &tree->file_entry; *last; last = &(*last)->next)
			;
		*last = xcalloc(1, sizeof(struct file_entry));
		(*last)->oid = *oid;
		(*last)->mode = mode;
		(*last)->name = xstrdup(pathname);
	}
	return 0;
}

static int load_one_tree_entry(struct lazy_tree *tree)
{
	const struct pathspec pathspec = { 0 };

	if (tree->loaded)
		return 0;
	if (is_place_holder_tree(tree))
		return 0;
	if (parse_tree(&tree->tree))
		return error("fail to parse tree: %s",
			     oid_to_hex(&tree->tree.object.oid));
	/* parse one level tree and fill file_entries and dir_entries */
	read_tree(the_repository, &tree->tree, &pathspec, fill_tree_entry,
		  tree);
	tree->loaded = 1;
	return 0;
}

/*
 * walk through root_tree to find a subtree which matches path in data.
 * The subtree found in root_tree will write back to cb_data.
 */
static int walk_tree(struct lazy_tree *root_tree, const char *path,
		     struct lazy_tree **endpoint, int flag)
{
	struct strbuf buf = STRBUF_INIT;
	char *p;
	struct lazy_tree *tree = root_tree;
	struct lazy_tree **subtree;

	if (!path)
		return error("it's insane to walk a null path");
	if (flag & MARK_TREE_DIRTY)
		root_tree->dirty = 1;

	/*
	 * Allocate a new buffer for strtok, because strtok may change
	 * the delimeter in the buffer to null character,
	 */
	strbuf_addstr(&buf, path);
	for (p = strtok(buf.buf, "/"); p; p = strtok(NULL, "/")) {
		/* load the tree we want to access */
		if (load_one_tree_entry(tree))
			return -1;

		/* work dir_entry matched with p */
		for (subtree = &tree->dir_entry; *subtree;
		     subtree = &(*subtree)->next) {
			if (!strcmp((*subtree)->name, p))
				break;
		}

		/* create new tree as a place-holder if fail to find p. */
		if (!*subtree) {
			*subtree = new_lazy_tree(p, NULL, 0);
			/* tree not in the repository */
			(*subtree)->dirty = 1;
		}
		tree = *subtree;

		/* We walk into tree and want to make some changes  */
		if (flag & MARK_TREE_DIRTY)
			tree->dirty = 1;
	}
	strbuf_release(&buf);

	/* Try to fill entries for the endpoint tree we found. */
	if (load_one_tree_entry(tree))
		return -1;
	if (endpoint)
		*endpoint = tree;
	return 0;
}

static int is_empty_tree(struct lazy_tree *tree)
{
	struct lazy_tree *tree_entry;
	struct file_entry *file_entry;

	/*
	 * If has a valid tree-id (not a place_holder), and not loaded yet,
	 * that means it's a non-empty tree, and we have no interesting to
	 * travel it.
	 */
	if (!tree->loaded && !is_place_holder_tree(tree))
		return 0;

	for (file_entry = tree->file_entry; file_entry;
	     file_entry = file_entry->next)
		return 0;

	for (tree_entry = tree->dir_entry; tree_entry;
	     tree_entry = tree_entry->next) {
		if (!is_empty_tree(tree_entry))
			return 0;
	}

	return 1;
}

static int do_ls_tree(struct lazy_tree *tree, const char *parent_dir)
{
	struct strbuf full_path = STRBUF_INIT;
	struct strbuf mark = STRBUF_INIT;
	struct lazy_tree *tree_entry;
	struct file_entry *file_entry;

	if (parent_dir && *parent_dir)
		strbuf_addstr(&full_path, parent_dir);
	if (*tree->name) {
		if (full_path.len)
			strbuf_addch(&full_path, '/');
		strbuf_addstr(&full_path, tree->name);
	}

	if (tree->dirty || !tree->loaded) {
		strbuf_addstr(&mark, " (");
		strbuf_addch(&mark, tree->dirty ? '!' : ' ');
		strbuf_addch(&mark, tree->loaded ? ' ' : '?');
		strbuf_addch(&mark, ')');
	}

	/* show this tree entry */
	fprintf(stderr, "%06o %s %*s %s%s\n", S_IFDIR,
		type_name(object_type(S_IFDIR)), (int)the_hash_algo->hexsz,
		!is_place_holder_tree(tree) ?
			oid_to_hex(&tree->tree.object.oid) :
			"",
		full_path.len ? full_path.buf : ".", mark.buf);

	for (tree_entry = tree->dir_entry; tree_entry;
	     tree_entry = tree_entry->next) {
		if (!is_empty_tree(tree_entry))
			do_ls_tree(tree_entry, full_path.buf);
	}

	for (file_entry = tree->file_entry; file_entry;
	     file_entry = file_entry->next) {
		/* show this file entry */
		fprintf(stderr, "%06o %s %s %s%s%s\n", file_entry->mode,
			type_name(object_type(file_entry->mode)),
			oid_to_hex(&file_entry->oid), full_path.buf,
			full_path.len ? "/" : "", file_entry->name);
	}

	strbuf_release(&full_path);
	strbuf_release(&mark);
	return 0;
}

static int do_ls_tree_path(struct lazy_tree *root_tree, const char *path)
{
	struct lazy_tree *tree;
	struct strbuf buf = STRBUF_INIT;
	int len;
	int ret;

	/* The input ppath is the tree we want to show, get the tree. */
	if (walk_tree(root_tree, path, &tree, 0))
		return -1;

	/* We should pass the parent_dir of the tree to do_ls_tree(). */
	len = strlen(path);
	while (path[len - 1] == '/' && len > 0)
		len--;
	while (len > 0 && path[len - 1] != '/')
		len--;
	while (path[len - 1] == '/' && len > 0)
		len--;
	strbuf_add(&buf, path, len);

	ret = do_ls_tree(tree, (const char *)buf.buf);

	strbuf_release(&buf);
	return ret;
}

static int do_rm_entry(struct lazy_tree *root_tree, const char *path, int force)
{
	struct strbuf buf = STRBUF_INIT;
	struct lazy_tree *tree;
	char *p;
	int len;
	struct lazy_tree **tree_entry;
	struct file_entry **file_entry;
	int ret = 0;

	/* walk to parent dir */
	len = strlen(path);
	while (path[len - 1] == '/' && len > 0)
		len--;
	while (len > 0 && path[len - 1] != '/')
		len--;
	strbuf_add(&buf, path, len);
	if (walk_tree(root_tree, buf.buf, &tree, MARK_TREE_DIRTY))
		return -1;

	/* find matched entry, and marked as deleted */
	strbuf_reset(&buf);
	p = (char *)path + len;
	len = strlen(p);
	while (p[len - 1] == '/' && len > 0)
		len--;
	strbuf_add(&buf, p, len);

	tree_entry = &tree->dir_entry;
	while (*tree_entry) {
		if (!strcmp(buf.buf, (*tree_entry)->name)) {
			struct lazy_tree *next = (*tree_entry)->next;
			free_one_tree_entry(*tree_entry);
			*tree_entry = next;
			goto cleanup;
		}
		tree_entry = &(*tree_entry)->next;
	}

	file_entry = &tree->file_entry;
	while (*file_entry) {
		if (!strcmp(buf.buf, (*file_entry)->name)) {
			struct file_entry *next = (*file_entry)->next;
			free_one_file_entry(*file_entry);
			*file_entry = next;
			goto cleanup;
		}
		file_entry = &(*file_entry)->next;
	}

	if (!force)
		ret = error("rm: %s: no such file or directory", path);

cleanup:
	strbuf_release(&buf);
	return ret;
}

static int do_rm(struct lazy_tree *root_tree, const char *buf)
{
	const char *path;
	int force = 0;

	/*
	 * Format:
	 *     [-f] SP name
	 */
	if (skip_prefix(buf, "-f ", &path))
		force = 1;
	else
		path = buf;

	return do_rm_entry(root_tree, path, force);
}

static int do_add_entry(struct lazy_tree *root_tree, unsigned mode,
			struct object_id *oid, const char *path, int force)
{
	struct strbuf buf = STRBUF_INIT;
	struct lazy_tree *tree;
	char *p;
	int len;
	struct lazy_tree **tree_entry;
	struct file_entry **file_entry;
	int ret = 0;
	enum object_type type;

	/* We check availability of oid except for submodules */
	type = object_type(mode);
	if (type != OBJ_COMMIT) {
		unsigned long unused;
		int obj_type;
		obj_type = oid_object_info(the_repository, oid, &unused);
		if (obj_type < 0)
			die("object %s is missing for path: %s",
			    oid_to_hex(oid), path);
		if (type != obj_type)
			die("unmatched types (actual: %s, want: %s)",
			    type_name(obj_type), type_name(type));
	}

	/* walk to parent dir */
	len = strlen(path);
	while (path[len - 1] == '/' && len > 0)
		len--;
	while (len > 0 && path[len - 1] != '/')
		len--;
	strbuf_add(&buf, path, len);
	if (walk_tree(root_tree, buf.buf, &tree, MARK_TREE_DIRTY))
		return -1;

	/* save entry name in buf */
	strbuf_reset(&buf);
	p = (char *)path + len;
	len = strlen(p);
	while (p[len - 1] == '/' && len > 0)
		len--;
	strbuf_add(&buf, p, len);

	/* add a tree entry */
	if (type == OBJ_TREE) {
		tree_entry = &tree->dir_entry;
		while (*tree_entry) {
			if (!strcmp(buf.buf, (*tree_entry)->name)) {
				if (oideq(&(*tree_entry)->tree.object.oid,
					  oid)) {
					if (!force)
						warning("already exist, ignored: %s",
							path);
					break;
				}
				if (force) {
					/* remove old tree_entry */
					struct lazy_tree *next =
						(*tree_entry)->next;
					free_one_tree_entry(*tree_entry);
					*tree_entry = next;
					/* Continue loop, until we cannot find a
					 * match entry. */
					continue;
				}
				ret = error(
					"found a conflict tree with different oid, please use replace command for it: %s",
					path);
				goto cleanup;
			}
			tree_entry = &(*tree_entry)->next;
		}
		/* not exist, add tree */
		if (!*tree_entry)
			*tree_entry = new_lazy_tree(buf.buf, oid, 0);
	}
	/* add a file entry */
	else {
		for (file_entry = &tree->file_entry; *file_entry;
		     file_entry = &(*file_entry)->next) {
			if (!strcmp(buf.buf, (*file_entry)->name)) {
				if ((*file_entry)->mode == mode &&
				    oideq(&(*file_entry)->oid, oid)) {
					if (!force)
						warning("already exist, ignored: %s",
							path);
					break;
				}
				if (force) {
					(*file_entry)->mode = mode;
					(*file_entry)->oid = *oid;
					break;
				}
				ret = error(
					"found a conflict entry with different mode or oid, please use replace command for it: %s",
					path);
				goto cleanup;
			}
		}
		/* not exist, add tree */
		if (!*file_entry) {
			*file_entry = xcalloc(1, sizeof(struct file_entry));
			(*file_entry)->mode = mode;
			(*file_entry)->oid = *oid;
			(*file_entry)->name = xstrdup(buf.buf);
		}
	}

cleanup:
	strbuf_release(&buf);
	return ret;
}

static int do_add(struct lazy_tree *root_tree, const char *buf)
{
	const char *ptr;
	const char *path, *p;
	char *ntr;
	unsigned mode;
	struct object_id oid;
	int force = 0;

	/*
	 * Format:
	 *     [-f] mode SP sha SP name
	 */
	if (skip_prefix(buf, "-f ", &ptr))
		force = 1;
	else
		ptr = buf;
	mode = strtoul(ptr, &ntr, 8);
	if (ptr == ntr || !ntr || *ntr != ' ')
		die("bad input for add: %s", buf);
	ptr = ntr + 1; /* sha */
	ntr = strchr(ptr, ' ');
	if (!ntr || parse_oid_hex(ptr, &oid, &p) || *p != ' ')
		die("bad input for add: %s", buf);
	path = p + 1;

	return do_add_entry(root_tree, mode, &oid, path, force);
}

static int do_add_tree(struct lazy_tree *root_tree, const char *buf)
{
	const char *ptr;
	const char *path, *p;
	struct object_id oid;
	int force = 0;

	/*
	 * Format:
	 *     [-f] SP sha SP name
	 */
	if (skip_prefix(buf, "-f ", &ptr))
		force = 1;
	else
		ptr = (char *)buf;
	if (parse_oid_hex(ptr, &oid, &p) || *p != ' ')
		die("bad input for add-tree: %s", buf);
	path = p + 1;

	return do_add_entry(root_tree, S_IFDIR, &oid, path, force);
}

static int do_replace_entry(struct lazy_tree *root_tree, unsigned mode,
			    struct object_id *oid, const char *path, int force)
{
	if (do_rm_entry(root_tree, path, force))
		return -1;
	if (do_add_entry(root_tree, mode, oid, path, force))
		return -1;
	return 0;
}

static int do_replace(struct lazy_tree *root_tree, const char *buf)
{
	const char *ptr;
	const char *path, *p;
	char *ntr;
	unsigned mode;
	struct object_id oid;
	int force = 0;

	/*
	 * Format:
	 *     [-f] SP mode SP sha SP name
	 */
	if (skip_prefix(buf, "-f ", &ptr))
		force = 1;
	else
		ptr = buf;

	mode = strtoul(ptr, &ntr, 8);
	if (ptr == ntr || !ntr || *ntr != ' ')
		die("bad input for add: %s", buf);
	ptr = ntr + 1; /* sha */
	ntr = strchr(ptr, ' ');
	if (!ntr || parse_oid_hex(ptr, &oid, &p) || *p != ' ')
		die("bad input for add: %s", buf);
	path = p + 1;

	return do_replace_entry(root_tree, mode, &oid, path, force);
}

static void append_to_tree(int *idx, unsigned mode, struct object_id *oid,
			   char *path)
{
	struct treeent *ent;
	if (strchr(path, '/'))
		die("path %s contains slash", path);

	ent = xcalloc(1, sizeof(*ent));
	ent->name = path;
	ent->len = strlen(path);
	ent->mode = mode;
	ent->oid = oid;

	ALLOC_GROW(entries, *idx + 1, alloc);
	entries[(*idx)++] = ent;
}

static int ent_compare(const void *a_, const void *b_)
{
	struct treeent *a = *(struct treeent **)a_;
	struct treeent *b = *(struct treeent **)b_;
	return base_name_compare(a->name, a->len, a->mode,
				 b->name, b->len, b->mode);
}

static int rehash_tree(struct lazy_tree *tree)
{
	struct lazy_tree *tree_entry;
	struct file_entry *file_entry;
	int used = 0;
	size_t size;
	int i;
	struct strbuf buf = STRBUF_INIT;

	for (tree_entry = tree->dir_entry; tree_entry;
	     tree_entry = tree_entry->next) {
		if (is_empty_tree(tree_entry))
			continue;
		append_to_tree(&used, S_IFDIR, &tree_entry->tree.object.oid,
			       tree_entry->name);
	}

	for (file_entry = tree->file_entry; file_entry;
	     file_entry = file_entry->next) {
		append_to_tree(&used, file_entry->mode, &file_entry->oid,
			       file_entry->name);
	}

	QSORT(entries, used, ent_compare);
	for (size = i = 0; i < used; i++)
		size += 32 + entries[i]->len;

	strbuf_init(&buf, size);
	for (i = 0; i < used; i++) {
		struct treeent *ent = entries[i];
		strbuf_addf(&buf, "%o %s%c", ent->mode, ent->name, '\0');
		strbuf_add(&buf, ent->oid->hash, the_hash_algo->rawsz);
	}

	write_object_file(buf.buf, buf.len, OBJ_TREE, &tree->tree.object.oid);
	strbuf_release(&buf);
	tree->dirty = 0;
	/* Make place-holder tree as loaded to prevent reload with duplicate
	 * entries */
	tree->loaded = 1;
	return 0;
}

static int do_commit(struct lazy_tree *tree)
{
	struct lazy_tree **tree_entry;
	int ret = 0;

	if (!tree->dirty)
		return 0;

	tree_entry = &tree->dir_entry;
	while (*tree_entry) {
		/* Remove empty subdir */
		if (is_empty_tree(*tree_entry)) {
			struct lazy_tree *next;
			next = (*tree_entry)->next;
			free_one_tree_entry(*tree_entry);
			*tree_entry = next;
			continue;
		}
		/* Commit dirty subdir */
		if ((*tree_entry)->dirty) {
			ret = do_commit(*tree_entry);
			if (ret)
				break;
		}
		tree_entry = &(*tree_entry)->next;
	}
	if (!ret)
		ret = rehash_tree(tree);
	return ret;
}

int cmd_edit_tree(int argc, const char **argv, const char *prefix)
{
	const char *input = NULL;
	FILE *reader;
	struct strbuf sb = STRBUF_INIT;
	struct object_id oid;
	int nul_term_line = 0;
	strbuf_getline_fn getline_fn;
	struct lazy_tree root_tree = { .name = "" };
	struct tree *tree;
	int ret = 0;

	const struct option edit_tree_options[] = {
		OPT_BOOL('z', NULL, &nul_term_line,
			 N_("input is NUL terminated")),
		OPT_FILENAME('f', "filename", &input, "read input from file"),
		OPT_END()
	};

	git_config(git_default_config, NULL);

	argc = parse_options(argc, argv, prefix, edit_tree_options,
			     edit_tree_usage, 0);
	getline_fn = nul_term_line ? strbuf_getline_nul : strbuf_getline_lf;

	if (argc < 1)
		usage_with_options(edit_tree_usage, edit_tree_options);

	if (get_oid(argv[0], &oid))
		die("Not a valid object name %s", argv[0]);

	/* Get tree object from commit or tag */
	tree = parse_tree_indirect(&oid);
	if (!tree)
		die("not a tree object: %s", argv[0]);

	/* Fill tree buffer with tree object's raw content. */
	root_tree.tree.object.oid = tree->object.oid;
	if (parse_tree(&root_tree.tree))
		die("not a tree object: %s", argv[0]);

	/* Read tree and fill file entries and direct subtree. */
	if (load_one_tree_entry(&root_tree))
		return -1;

	if (input) {
		reader = fopen(input, "r");
		if (!reader)
			die_errno("fail to open %s", input);
	} else {
		reader = stdin;
	}

	while (getline_fn(&sb, reader) != EOF && !ret) {
		const char *p;

		if (*sb.buf == '#' || !*sb.buf)
			continue;
		if (skip_prefix(sb.buf, "walk ", &p))
			ret = walk_tree(&root_tree, p, NULL, 0);
		else if (skip_prefix(sb.buf, "ls-tree ", &p))
			ret = do_ls_tree_path(&root_tree, p);
		else if (!strcmp(sb.buf, "ls-tree"))
			ret = do_ls_tree_path(&root_tree, "");
		else if (skip_prefix(sb.buf, "echo ", &p))
			fprintf(stderr, "%s\n", p);
		else if (!strcmp(sb.buf, "echo"))
			fprintf(stderr, "\n");
		else if (skip_prefix(sb.buf, "add ", &p))
			ret = do_add(&root_tree, p);
		else if (skip_prefix(sb.buf, "add-tree ", &p))
			ret = do_add_tree(&root_tree, p);
		else if (skip_prefix(sb.buf, "replace ", &p))
			ret = do_replace(&root_tree, p);
		else if (skip_prefix(sb.buf, "rm ", &p))
			ret = do_rm(&root_tree, p);
		else if (!strcmp(sb.buf, "commit"))
			ret = do_commit(&root_tree);
		else
			ret = error("unknown command: %s", sb.buf);
	}

	if (reader != stdin)
		fclose(reader);

	if (!ret)
		ret = do_commit(&root_tree);
	if (!ret)
		printf("%s\n", oid_to_hex(&root_tree.tree.object.oid));

	strbuf_release(&sb);
	return ret;
}
