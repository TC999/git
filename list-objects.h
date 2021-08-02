#ifndef LIST_OBJECTS_H
#define LIST_OBJECTS_H

struct commit;
struct object;
struct rev_info;

struct show_info {
    void *show_data; /* the data necessary for showing the object */
    void *show_cache; /* the cache ownership relationship data for showing the object */
};

typedef void (*show_commit_fn)(struct commit *, struct show_info *);
typedef void (*show_object_fn)(struct object *, const char *, struct show_info *);
void traverse_commit_list(struct rev_info *, show_commit_fn, show_object_fn, void *show_data);

typedef void (*show_edge_fn)(struct commit *);
void mark_edges_uninteresting(struct rev_info *revs,
			      show_edge_fn show_edge,
			      int sparse);

struct oidset;
struct list_objects_filter_options;

void traverse_commit_list_filtered(
	struct list_objects_filter_options *filter_options,
	struct rev_info *revs,
	show_commit_fn show_commit,
	show_object_fn show_object,
	void *show_data,
	struct oidset *omitted);

#endif /* LIST_OBJECTS_H */
