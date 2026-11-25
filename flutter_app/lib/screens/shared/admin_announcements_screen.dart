
part of '../../main.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends State<AdminAnnouncementsScreen> {
  List<Map<String, dynamic>> announcements = [];

  bool loading = true;
  bool processing = false;
  String? errorMessage;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
  }

  bool isPublished(Map<String, dynamic> item) {
    final value = item['is_published'];

    return value == true ||
        value == 1 ||
        value == '1';
  }

  int get publishedCount =>
      announcements.where(isPublished).length;

  int get draftCount =>
      announcements.length - publishedCount;

  List<Map<String, dynamic>> get filteredAnnouncements {
    if (selectedFilter == 'published') {
      return announcements.where(isPublished).toList();
    }

    if (selectedFilter == 'drafts') {
      return announcements
          .where((item) => !isPublished(item))
          .toList();
    }

    return announcements;
  }

  Future<void> loadAnnouncements() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await Api.request(
        'GET',
        '/admin/announcements',
      );

      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;

      setState(() {
        announcements = rows;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = err(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();

    if (date == null) return 'Date unavailable';

    return '${date.day}/${date.month}/${date.year}';
  }

  IconData categoryIcon(String category) {
    switch (category) {
      case 'maintenance':
        return Icons.build_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }

  Color categoryColor(String category) {
    switch (category) {
      case 'maintenance':
        return const Color(0xFFD97706);
      case 'event':
        return const Color(0xFF16856A);
      case 'emergency':
        return const Color(0xFFDC2626);
      default:
        return ocean;
    }
  }

  Future<void> openEditor([
    Map<String, dynamic>? existing,
  ]) async {
    if (processing) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementEditor(
          existing: existing,
        ),
      ),
    );

    if (changed == true && mounted) {
      await loadAnnouncements();
    }
  }

  Future<bool> confirmAction({
    required String title,
    required String message,
    required String buttonText,
    Color buttonColor = navy,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: buttonColor,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(buttonText),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> publishAnnouncement(
    Map<String, dynamic> item,
  ) async {
    if (processing) return;

    final confirmed = await confirmAction(
      title: 'Publish announcement?',
      message:
          'This announcement will become visible '
          'to approved residents.',
      buttonText: 'Publish',
    );

    if (!confirmed || !mounted || processing) return;

    setState(() => processing = true);

    try {
      await Api.request(
        'PUT',
        '/admin/announcements/${item['id']}/publish',
      );

      if (mounted) {
        toast(context, 'Announcement published successfully');
        await loadAnnouncements();
      }
    } catch (e) {
      if (mounted) toast(context, err(e));
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  Future<void> deleteAnnouncement(
    Map<String, dynamic> item,
  ) async {
    if (processing) return;

    final confirmed = await confirmAction(
      title: 'Delete announcement?',
      message:
          'Are you sure you want to delete '
          '"${item['title']}"? '
          'This action cannot be undone.',
      buttonText: 'Delete',
      buttonColor: Colors.red,
    );

    if (!confirmed || !mounted || processing) return;

    setState(() => processing = true);

    try {
      await Api.request(
        'DELETE',
        '/admin/announcements/${item['id']}',
      );

      if (mounted) {
        toast(context, 'Announcement deleted successfully');
        await loadAnnouncements();
      }
    } catch (e) {
      if (mounted) toast(context, err(e));
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  Widget statCard(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: navy.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: ocean,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget announcementCard(Map<String, dynamic> item) {
    final category = '${item['category'] ?? 'general'}';
    final priority = '${item['priority'] ?? 'normal'}';
    final published = isPublished(item);
    final color = categoryColor(category);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: navy.withValues(alpha: 0.09),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      color.withValues(alpha: 0.12),
                  child: Icon(
                    categoryIcon(category),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item['title'] ?? 'Announcement'}',
                        style: const TextStyle(
                          color: navy,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    published ? 'Published' : 'Draft',
                    style: TextStyle(
                      color: published
                          ? const Color(0xFF16856A)
                          : const Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: published
                      ? const Color(0xFFDDF5E7)
                      : const Color(0xFFFFF0D3),
                ),
                Chip(
                  label: Text(
                    capitalize(priority),
                    style: TextStyle(
                      fontSize: 11,
                      color: priority == 'urgent'
                          ? Colors.red
                          : priority == 'important'
                              ? const Color(0xFFD97706)
                              : navy,
                    ),
                  ),
                  backgroundColor: pale,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item['content'] ?? ''}',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: ocean,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    published
                        ? 'Published: ${formatDate(item['published_at'])}'
                        : 'Created: ${formatDate(item['created_at'])}',
                    style: const TextStyle(
                      color: ocean,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!published)
                  FilledButton.icon(
                    onPressed: processing
                        ? null
                        : () => publishAnnouncement(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Publish'),
                  ),
                OutlinedButton.icon(
                  onPressed: processing
                      ? null
                      : () => openEditor(item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: processing
                      ? null
                      : () => deleteAnnouncement(item),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredAnnouncements;

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        title: const Text(
          'Manage Announcements',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading || processing
                ? null
                : loadAnnouncements,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh announcements',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!processing && !loading) {
            await loadAnnouncements();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navy, ocean],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Community communication',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create and manage important updates '
                    'for your residents.',
                    style: TextStyle(
                      color: pale,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                statCard(
                  'Total',
                  announcements.length,
                  Icons.campaign_outlined,
                  navy,
                ),
                const SizedBox(width: 10),
                statCard(
                  'Published',
                  publishedCount,
                  Icons.check_circle_outline,
                  const Color(0xFF16856A),
                ),
                const SizedBox(width: 10),
                statCard(
                  'Drafts',
                  draftCount,
                  Icons.edit_note,
                  const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: processing || loading
                  ? null
                  : () => openEditor(),
              style: FilledButton.styleFrom(
                backgroundColor: ocean,
                padding: const EdgeInsets.all(17),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Announcement'),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: ['all', 'published', 'drafts']
                  .map((filter) {
                return ChoiceChip(
                  label: Text(capitalize(filter)),
                  selected: selectedFilter == filter,
                  selectedColor: pale,
                  onSelected: (_) {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Announcements',
                    style: TextStyle(
                      color: navy,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${items.length} records',
                  style: const TextStyle(
                    color: ocean,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (processing)
              const LinearProgressIndicator(),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: loadAnnouncements,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 60,
                      color: ocean,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No announcements found',
                      style: TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...items.map(announcementCard),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ANNOUNCEMENT CREATE / EDIT FORM
// =====================================================

class AnnouncementEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AnnouncementEditor({
    super.key,
    this.existing,
  });

  @override
  State<AnnouncementEditor> createState() =>
      _AnnouncementEditorState();
}

class _AnnouncementEditorState
    extends State<AnnouncementEditor> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController contentController;

  String category = 'general';
  String priority = 'normal';

  bool saving = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: '${widget.existing?['title'] ?? ''}',
    );

    contentController = TextEditingController(
      text: '${widget.existing?['content'] ?? ''}',
    );

    category =
        '${widget.existing?['category'] ?? 'general'}';

    priority =
        '${widget.existing?['priority'] ?? 'normal'}';
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();

    super.dispose();
  }

  String capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> saveAnnouncement() async {
    if (saving) return;

    if (!formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      'content': contentController.text.trim(),
      'category': category,
      'priority': priority,
    };

    try {
      if (isEditing) {
        await Api.request(
          'PUT',
          '/admin/announcements/${widget.existing!['id']}',
          data,
        );
      } else {
        await Api.request(
          'POST',
          '/admin/announcements',
          data,
        );
      }

      if (!mounted) return;

      toast(
        context,
        isEditing
            ? 'Announcement updated successfully'
            : 'Announcement saved as draft',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, err(e));
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          title: Text(
            isEditing
                ? 'Edit Announcement'
                : 'Create Announcement',
            style: const TextStyle(
              color: navy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      color: Colors.white,
                      size: 35,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEditing
                          ? 'Update community news'
                          : 'Share a community update',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEditing
                          ? 'Update the announcement information.'
                          : 'New announcements are saved as drafts '
                              'until you publish them.',
                      style: const TextStyle(
                        color: pale,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: titleController,
                enabled: !saving,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Announcement title',
                  hintText: 'Enter announcement title',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter a title';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  'general',
                  'maintenance',
                  'event',
                  'emergency',
                ].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(capitalize(value)),
                  );
                }).toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => category = value);
                        }
                      },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  'normal',
                  'important',
                  'urgent',
                ].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(capitalize(value)),
                  );
                }).toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => priority = value);
                        }
                      },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: contentController,
                enabled: !saving,
                maxLength: 10000,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Announcement content',
                  hintText: 'Write your community update...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Please enter announcement content';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    saving ? null : saveAnnouncement,
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                  padding: const EdgeInsets.all(17),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving
                      ? 'Saving...'
                      : isEditing
                          ? 'Save Changes'
                          : 'Save as Draft',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
