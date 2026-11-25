
part of '../../main.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState
    extends State<AnnouncementsScreen> {
  List<Map<String, dynamic>> announcements = [];

  bool loading = true;
  String? errorMessage;
  String selectedCategory = 'all';

  final categories = const [
    'all',
    'general',
    'maintenance',
    'event',
    'emergency',
  ];

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
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
        '/announcements',
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

  List<Map<String, dynamic>> get filteredAnnouncements {
    if (selectedCategory == 'all') {
      return announcements;
    }

    return announcements.where((item) {
      return item['category'] == selectedCategory;
    }).toList();
  }

  String capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
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

  Color priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFDC2626);
      case 'important':
        return const Color(0xFFD97706);
      default:
        return ocean;
    }
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();

    if (date == null) return 'Date unavailable';

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void openAnnouncement(Map<String, dynamic> item) {
    final category = '${item['category'] ?? 'general'}';
    final priority = '${item['priority'] ?? 'normal'}';
    final color = categoryColor(category);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: canvas,
          appBar: AppBar(
            title: const Text('Announcement Details'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(
                        categoryIcon(category),
                        color: color,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(capitalize(category)),
                        ),
                        Chip(
                          label: Text(
                            capitalize(priority),
                            style: TextStyle(
                              color: priorityColor(priority),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: priorityColor(priority)
                              .withValues(alpha: 0.10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${item['title'] ?? 'Announcement'}',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatDate(item['published_at']),
                      style: const TextStyle(
                        color: ocean,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${item['content'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(
                          Icons.apartment_outlined,
                          color: ocean,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Published by Juristic Management',
                            style: TextStyle(
                              color: ocean,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget announcementCard(Map<String, dynamic> item) {
    final category = '${item['category'] ?? 'general'}';
    final priority = '${item['priority'] ?? 'normal'}';

    final color = categoryColor(category);
    final priorityTint = priorityColor(priority);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: navy.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openAnnouncement(item),
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
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      categoryIcon(category),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
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
              const SizedBox(height: 14),
              if (priority != 'normal')
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: priorityTint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    capitalize(priority),
                    style: TextStyle(
                      color: priorityTint,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              Text(
                '${item['content'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: ocean,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      formatDate(item['published_at']),
                      style: const TextStyle(
                        color: ocean,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Text(
                    'Read more',
                    style: TextStyle(
                      color: navy,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: navy,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
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
          'Community Announcements',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadAnnouncements,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh announcements',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadAnnouncements,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Stay informed.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Stay connected with the latest news, events '
                    'and important updates from your community.',
                    style: TextStyle(
                      color: pale,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(capitalize(category)),
                      selected: selectedCategory == category,
                      selectedColor: pale,
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Latest announcements',
                    style: TextStyle(
                      color: navy,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${items.length} updates',
                  style: const TextStyle(
                    color: ocean,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
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
                    const Icon(
                      Icons.error_outline,
                      size: 45,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: loadAnnouncements,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 45),
                child: Column(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: ocean,
                      size: 65,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'No announcements yet',
                      style: TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Community updates will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ocean),
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
