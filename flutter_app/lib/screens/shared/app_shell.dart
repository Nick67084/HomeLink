part of '../../main.dart';

class Shell extends StatefulWidget {
  final Map<String, dynamic> user;

  const Shell({
    super.key,
    required this.user,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  int unreadCount = 0;

  bool dashboardLoading = false;

  List<Map<String, dynamic>> upcomingBookings = [];
  List<Map<String, dynamic>> featuredFacilities = [];

  bool get isAdmin => widget.user['role'] == 'juristic';

  List<Module> get modules => isAdmin ? adminModules : residentModules;

  @override
  void initState() {
    super.initState();
    loadNotifications();

    if (!isAdmin) {
      loadResidentDashboard();
    }
  }

  Future<void> loadNotifications() async {
    try {
      final result = await Api.request(
        'GET',
        '/notifications/unread-count',
      );

      if (mounted) {
        setState(() {
          unreadCount = (result['unread_count'] as num).toInt();
        });
      }
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    }
  }

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeLinkNotificationsScreen(),
      ),
    ).then((_) {
      loadNotifications();
    });
  }

  Future<void> loadResidentDashboard() async {
    if (!mounted) return;

    setState(() => dashboardLoading = true);

    try {
      final results = await Future.wait([
        Api.request('GET', '/bookings/my'),
        Api.request('GET', '/facilities'),
      ]);

      final bookings = (results[0] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final facilities = (results[1] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final now = DateTime.now();

      final upcoming = bookings.where((booking) {
        final status = '${booking['status'] ?? ''}';

        if (status != 'pending' && status != 'approved') {
          return false;
        }

        final start = DateTime.tryParse(
          '${booking['start_at'] ?? ''}',
        );

        return start != null && start.isAfter(now);
      }).toList();

      upcoming.sort((a, b) {
        final aDate = DateTime.tryParse(
          '${a['start_at'] ?? ''}',
        );

        final bDate = DateTime.tryParse(
          '${b['start_at'] ?? ''}',
        );

        if (aDate == null || bDate == null) return 0;

        return aDate.compareTo(bDate);
      });

      if (mounted) {
        setState(() {
          upcomingBookings = upcoming;
          featuredFacilities = facilities.take(3).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    } finally {
      if (mounted) {
        setState(() => dashboardLoading = false);
      }
    }
  }

  Future<void> signout() async {
    await Api.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
        (_) => false,
      );
    }
  }

  void open(Module m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (m.path == '/announcements') {
            return const AnnouncementsScreen();
          }

          if (m.path == '/admin/announcements' && isAdmin) {
            return const AdminAnnouncementsScreen();
          }

          return RecordsScreen(
            module: m,
            isAdmin: isAdmin,
            user: widget.user,
          );
        },
      ),
    ).then((_) {
      if (!mounted) return;

      if (!isAdmin) {
        loadResidentDashboard();
      }

      loadNotifications();
    });
  }

  void openPath(
    String title,
    String path,
    IconData icon,
  ) {
    open(Module(title, path, icon));
  }

  String facilityPhoto(Map<String, dynamic> facility) {
    final uploaded = facility['image_url']?.toString().trim();

    if (uploaded != null &&
        (uploaded.startsWith('https://') || uploaded.startsWith('http://'))) {
      return uploaded;
    }

    final name = '${facility['name'] ?? ''}'.toLowerCase();

    if (name.contains('fitness') || name.contains('gym')) {
      return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=900&auto=format&fit=crop&q=85';
    }

    if (name.contains('meeting')) {
      return 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=900&auto=format&fit=crop&q=85';
    }

    if (name.contains('study')) {
      return 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=900&auto=format&fit=crop&q=85';
    }

    return 'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?w=900&auto=format&fit=crop&q=85';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomeLink',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        actions: [
          IconButton(
            onPressed: openNotifications,
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
              ),
              child: const Icon(
                Icons.notifications_outlined,
              ),
            ),
          ),
          if (!isAdmin)
            IconButton(
              onPressed: () {
                loadResidentDashboard();
                loadNotifications();
              },
              icon: const Icon(
                Icons.refresh_outlined,
              ),
              tooltip: 'Refresh dashboard',
            ),
          IconButton(
            onPressed: signout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            dashboard(),
            modulesPage(),
            RecordsScreen(
              module: isAdmin ? adminModules[1] : residentModules[1],
              isAdmin: isAdmin,
              user: widget.user,
              embedded: true,
            ),
            profile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) {
          setState(() => tab = v);

          if (v == 0 && !isAdmin) {
            loadResidentDashboard();
          }

          loadNotifications();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(
              Icons.grid_view_outlined,
            ),
            label: isAdmin ? 'Manage' : 'Services',
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: isAdmin ? 'Requests' : 'Activity',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    return isAdmin ? adminDashboard() : residentDashboard();
  }

  // =====================================================
  // RESIDENT DASHBOARD
  // =====================================================

  Widget residentDashboard() {
    final name = '${widget.user['full_name'] ?? 'Resident'}';

    final building = '${widget.user['building'] ?? '-'}';

    final unit = '${widget.user['unit_number'] ?? '-'}';

    return RefreshIndicator(
      onRefresh: () async {
        await loadResidentDashboard();
        await loadNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Welcome home, $name!',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: ocean,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                'Building $building · Unit $unit',
                style: const TextStyle(
                  color: ocean,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Luxury condominium welcome image
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: SizedBox(
              height: 235,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?w=1400&auto=format&fit=crop&q=85',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: navy),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          navy.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Community.\nYour Home.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Experience a better way of community living.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => openPath(
                            'Facilities',
                            '/facilities',
                            Icons.meeting_room_outlined,
                          ),
                          icon: const Icon(
                            Icons.explore_outlined,
                          ),
                          label: const Text(
                            'Explore Facilities',
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: navy,
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 27),
          sectionHeading('Quick Access'),
          const SizedBox(height: 13),

          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 105,
            children: [
              quickAction(
                'My Bookings',
                'Manage reservations',
                Icons.event_available_outlined,
                () => openPath(
                  'My Bookings',
                  '/bookings/my',
                  Icons.event_available_outlined,
                ),
              ),
              quickAction(
                'Repairs',
                'Report an issue',
                Icons.build_outlined,
                () => openPath(
                  'Repairs',
                  '/repairs/my',
                  Icons.build_outlined,
                ),
              ),
              quickAction(
                'Parcels',
                'Track deliveries',
                Icons.inventory_2_outlined,
                () => openPath(
                  'Parcels',
                  '/parcels/my',
                  Icons.inventory_2_outlined,
                ),
              ),
              quickAction(
                'Messages',
                'Contact management',
                Icons.chat_bubble_outline,
                () => openPath(
                  'Messages',
                  '/messages/my',
                  Icons.chat_bubble_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 27),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionHeading('Upcoming Bookings'),
              TextButton(
                onPressed: () => openPath(
                  'My Bookings',
                  '/bookings/my',
                  Icons.event_available_outlined,
                ),
                child: const Text('View all'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (dashboardLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (upcomingBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                color: pale,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    color: navy,
                    size: 28,
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'No upcoming bookings yet.\nExplore our community facilities!',
                      style: TextStyle(
                        color: navy,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...upcomingBookings.take(2).map(bookingCard),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionHeading('Explore Our Facilities'),
              TextButton(
                onPressed: () => openPath(
                  'Facilities',
                  '/facilities',
                  Icons.meeting_room_outlined,
                ),
                child: const Text('See all'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (featuredFacilities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No facilities available right now.',
                style: TextStyle(color: ocean),
              ),
            )
          else
            ...featuredFacilities.map(
              featuredFacilityCard,
            ),

          const SizedBox(height: 28),
          sectionHeading('More Community Services'),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: residentModules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (c, i) => serviceTile(residentModules[i]),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    );
  }

  Widget quickAction(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: navy.withValues(alpha: 0.09),
          ),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: pale,
              child: Icon(icon, color: navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: navy,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ocean,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bookingCard(
    Map<String, dynamic> booking,
  ) {
    final name = '${booking['facility_name'] ?? 'Facility Booking'}';

    final status = '${booking['status'] ?? 'pending'}';

    final start = DateTime.tryParse(
      '${booking['start_at'] ?? ''}',
    )?.toLocal();

    String dateText = 'Date unavailable';

    if (start != null) {
      dateText = '${start.day}/${start.month}/${start.year} '
          'at ${start.hour.toString().padLeft(2, '0')}:'
          '${start.minute.toString().padLeft(2, '0')}';
    }

    final isApproved = status == 'approved';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: pale,
              child: Icon(
                Icons.event_available_outlined,
                color: navy,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ocean,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                ),
              ),
              backgroundColor: isApproved
                  ? const Color(0xFFDDF5E7)
                  : const Color(0xFFFFF0D3),
            ),
          ],
        ),
      ),
    );
  }

  Widget featuredFacilityCard(
    Map<String, dynamic> facility,
  ) {
    final name = '${facility['name'] ?? 'Facility'}';

    return InkWell(
      onTap: () => openPath(
        'Facilities',
        '/facilities',
        Icons.meeting_room_outlined,
      ),
      borderRadius: BorderRadius.circular(19),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 125,
              height: 115,
              child: Image.network(
                facilityPhoto(facility),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: pale,
                  child: const Icon(
                    Icons.apartment,
                    color: navy,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${facility['location'] ?? 'Community facility'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ocean,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Text(
                          'Explore & Book',
                          style: TextStyle(
                            fontSize: 12,
                            color: navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward,
                          color: navy,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ADMIN DASHBOARD
  // =====================================================

  Widget adminStatistics() {
    return FutureBuilder<dynamic>(
      future: Api.request('GET', '/admin/dashboard'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data is! Map) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Unable to load dashboard statistics.',
              ),
            ),
          );
        }

        final data = snapshot.data as Map;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 4 : 2,
            mainAxisExtent: 145,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            adminStatCard(
              'Total Residents',
              data['total_residents'],
              Icons.people_alt_outlined,
              ocean,
            ),
            adminStatCard(
              'Pending Approvals',
              data['pending_approvals'],
              Icons.person_add_alt_1_outlined,
              Colors.orange,
            ),
            adminStatCard(
              'Pending Bookings',
              data['pending_bookings'],
              Icons.event_available_outlined,
              ocean,
            ),
            adminStatCard(
              'Active Repairs',
              data['active_repairs'],
              Icons.build_outlined,
              Colors.orange,
            ),
            adminStatCard(
              'Unclaimed Parcels',
              data['unclaimed_parcels'],
              Icons.inventory_2_outlined,
              ocean,
            ),
            adminStatCard(
              'Unpaid Bills',
              data['unpaid_bills'],
              Icons.receipt_long_outlined,
              Colors.red,
            ),
            adminStatCard(
              'Pending Services',
              data['pending_service_requests'],
              Icons.handyman_outlined,
              Colors.orange,
            ),
            adminStatCard(
              'Published Announcements',
              data['published_announcements'],
              Icons.campaign_outlined,
              Colors.teal,
            ),
          ],
        );
      },
    );
  }

  Widget adminStatCard(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE3EBF2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              '${value ?? "—"}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget adminDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await loadNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hello, ${widget.user['full_name'] ?? 'Admin'}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const Text(
            'Juristic management dashboard',
            style: TextStyle(color: ocean),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage your community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Review requests and support your residents.',
                  style: TextStyle(color: pale),
                ),
                const SizedBox(height: 15),
                OutlinedButton(
                  onPressed: () => setState(() => tab = 1),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Open management',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

// COMMUNITY OVERVIEW

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Community Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              IconButton(
                tooltip: 'Refresh statistics',
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(
                  Icons.refresh,
                  color: ocean,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            'Live statistics from your community',
            style: TextStyle(
              fontSize: 13,
              color: ocean,
            ),
          ),

          const SizedBox(height: 16),

          adminStatistics(),

          const SizedBox(height: 24),

// MANAGEMENT TOOLS
          const Text(
            'Management Tools',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: adminModules.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 120,
            ),
            itemBuilder: (c, i) => serviceTile(adminModules[i]),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SHARED COMPONENTS
  // =====================================================

  Widget serviceTile(Module m) {
    return InkWell(
      onTap: () => open(m),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: pale,
                child: Icon(m.icon, color: navy),
              ),
              const SizedBox(height: 9),
              Text(
                m.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget modulesPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isAdmin ? 'Management' : 'Services',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 12),
        ...modules.map(
          (m) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: pale,
                child: Icon(m.icon, color: navy),
              ),
              title: Text(m.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(m),
            ),
          ),
        ),
      ],
    );
  }

  Widget profile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(
          Icons.account_circle,
          size: 76,
          color: navy,
        ),
        const SizedBox(height: 16),
        ...[
          'full_name',
          'email',
          'phone',
          'role',
          'building',
          'unit_number',
        ].map(
          (k) => Card(
            child: ListTile(
              title: Text(
                k.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  color: ocean,
                ),
              ),
              subtitle: Text(
                '${widget.user[k] ?? '-'}',
              ),
            ),
          ),
        ),
        if (widget.user['approved'] == 0 || widget.user['approved'] == false)
          const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text(
                'Account awaiting juristic approval',
              ),
            ),
          ),
        FilledButton.tonal(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileEditor(
                user: widget.user,
              ),
            ),
          ).then((changed) {
            if (changed == true) {
              Api.request('GET', '/me').then((u) {
                if (mounted) {
                  setState(() {
                    widget.user.addAll(
                      Map<String, dynamic>.from(u),
                    );
                  });
                }
              });
            }
          }),
          child: const Text('Edit profile'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: signout,
          child: const Text('Log out'),
        ),
      ],
    );
  }
}

// =====================================================
// HOMELINK NOTIFICATION SCREEN
// =====================================================

class HomeLinkNotificationsScreen extends StatefulWidget {
  const HomeLinkNotificationsScreen({super.key});

  @override
  State<HomeLinkNotificationsScreen> createState() =>
      _HomeLinkNotificationsScreenState();
}

class _HomeLinkNotificationsScreenState
    extends State<HomeLinkNotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];

  bool loading = true;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    if (!mounted) return;

    setState(() => loading = true);

    try {
      final result = await Api.request(
        'GET',
        '/notifications',
      );

      if (!mounted) return;

      setState(() {
        notifications =
            (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  bool isUnread(Map<String, dynamic> notification) {
    final value = notification['is_read'];

    return value == false || value == 0 || value == '0';
  }

  Future<void> markAsRead(
    Map<String, dynamic> notification,
  ) async {
    if (!isUnread(notification) || processing) {
      return;
    }

    setState(() => processing = true);

    try {
      await Api.request(
        'PUT',
        '/notifications/${notification['id']}/read',
      );

      await loadNotifications();
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (processing) return;

    setState(() => processing = true);

    try {
      await Api.request(
        'PUT',
        '/notifications/read-all',
      );

      await loadNotifications();
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    } finally {
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  IconData notificationIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.event_available_outlined;

      case 'repair':
        return Icons.build_outlined;

      case 'parcel':
        return Icons.inventory_2_outlined;

      case 'announcement':
        return Icons.campaign_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }

  Color notificationColor(String type) {
    switch (type) {
      case 'booking':
        return const Color(0xFF16856A);

      case 'repair':
        return const Color(0xFFE19A35);

      case 'parcel':
        return const Color(0xFF367CCB);

      case 'announcement':
        return const Color(0xFF8756B8);

      default:
        return navy;
    }
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();

    if (date == null) return '';

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where(isUnread).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: processing ? null : markAllAsRead,
              icon: const Icon(
                Icons.done_all,
                size: 19,
              ),
              label: const Text(
                'Mark all as read',
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 130),
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 75,
                        color: ocean,
                      ),
                      SizedBox(height: 18),
                      Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Your community updates will appear here.',
                          style: TextStyle(
                            color: ocean,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '$unread unread notification${unread == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: ocean,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...notifications.map(
                        (notification) {
                          final type = '${notification['type'] ?? 'general'}';

                          final unreadNotification = isUnread(notification);

                          final color = notificationColor(type);

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            elevation: 0,
                            color: unreadNotification
                                ? const Color(
                                    0xFFEAF3FC,
                                  )
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                17,
                              ),
                              side: BorderSide(
                                color: unreadNotification
                                    ? const Color(
                                        0xFFB9D7F3,
                                      )
                                    : const Color(
                                        0xFFE8EDF3,
                                      ),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                17,
                              ),
                              onTap: () => markAsRead(
                                notification,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: color.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        notificationIcon(
                                          type,
                                        ),
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 13,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${notification['title'] ?? 'Notification'}',
                                                  style: TextStyle(
                                                    color: navy,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        unreadNotification
                                                            ? FontWeight.bold
                                                            : FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (unreadNotification)
                                                Container(
                                                  width: 9,
                                                  height: 9,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(
                                                      0xFF2879C8,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: 7,
                                          ),
                                          Text(
                                            '${notification['message'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: ocean,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 10,
                                          ),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 13,
                                                color: ocean,
                                              ),
                                              const SizedBox(
                                                width: 5,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  formatDate(
                                                    notification['created_at'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: ocean,
                                                  ),
                                                ),
                                              ),
                                              if (unreadNotification)
                                                const Text(
                                                  'Tap to mark as read',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(
                                                      0xFF2879C8,
                                                    ),
                                                    fontWeight: FontWeight.w600,
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
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}
