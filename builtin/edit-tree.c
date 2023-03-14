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
		else
			ret = error("unknown command: %s", sb.buf);
	}

	if (reader != stdin)
		fclose(reader);

	strbuf_release(&sb);
	return ret;
}
