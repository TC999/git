/*
 * GIT - the stupid content tracker
 *
 * Copyright (c) Jiang Xin, 2023
 */
#include "builtin.h"
#include "config.h"
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
		else
			ret = error("unknown command: %s", sb.buf);
	}

	if (reader != stdin)
		fclose(reader);

	strbuf_release(&sb);
	return ret;
}
