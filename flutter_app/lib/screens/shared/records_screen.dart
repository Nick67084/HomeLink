part of '../../main.dart';

class RecordsScreen extends StatefulWidget {
  final Module module;
  final bool isAdmin;
  final Map<String, dynamic> user;
  final bool embedded;

  const RecordsScreen({
    super.key,
    required this.module,
    required this.isAdmin,
    required this.user,
    this.embedded = false,
  });

  @override
  State<RecordsScreen> createState() => _RecordsState();
}

class _RecordsState extends State<RecordsScreen> {
  bool busy = true;
  String? failure;
  List<Map<String, dynamic>> items = [];

  String get path => widget.module.path;
  bool get isFacilities => path == '/facilities';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => busy = true);

    try {
      final result = await Api.request('GET', path);

      if (mounted) {
        setState(() {
          items = (result as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          failure = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = err(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get canAdd =>
      (!widget.isAdmin &&
          [
            '/repairs/my',
            '/vehicles/my',
            '/suggestions/my',
            '/bookings/my',
            '/messages/my',
            '/service-requests/my',
          ].contains(path)) ||
      (widget.isAdmin &&
          [
            '/admin/parcels',
            '/admin/bills',
            '/rules',
          ].contains(path));

  Future<void> add() async {
    if (path == '/bookings/my' || path == '/service-requests/my') {
      final target = path == '/bookings/my'
          ? const Module(
              'Facilities',
              '/facilities',
              Icons.meeting_room,
            )
          : const Module(
              'Home Services',
              '/services',
              Icons.cleaning_services,
            );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordsScreen(
            module: target,
            isAdmin: false,
            user: widget.user,
          ),
        ),
      );

      await load();
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordForm(
          path: path,
          user: widget.user,
        ),
      ),
    );

    if (result == true) load();
  }

  Future<void> action(
    String method,
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      await Api.request(method, endpoint, body);

      if (mounted) toast(context, 'Saved successfully');

      await load();
    } catch (e) {
      if (mounted) toast(context, err(e));
    }
  }

  // Facility-specific demo photographs.
  // Uploaded facility images take priority when available.
  String demoPhoto(String name) {
    final n = name.toLowerCase();

    if (n.contains('fitness') || n.contains('gym')) {
      return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=85';
    }

    if (n.contains('meeting')) {
      return 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1200&auto=format&fit=crop&q=85';
    }

    if (n.contains('study')) {
      return 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&auto=format&fit=crop&q=85';
    }

    return 'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?w=1200&auto=format&fit=crop&q=85';
  }

  String facilityPhoto(Map<String, dynamic> facility) {
    final uploaded = facility['image_url']?.toString().trim();

    if (uploaded != null &&
        (uploaded.startsWith('https://') || uploaded.startsWith('http://'))) {
      return uploaded;
    }

    return demoPhoto('${facility['name'] ?? ''}');
  }

  void bookFacility(Map<String, dynamic> facility) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordForm(
          path: '/bookings/my',
          user: widget.user,
          selectedId: facility['id'],
        ),
      ),
    ).then((_) => load());
  }

  Widget facilityCard(Map<String, dynamic> facility) {
    final name = '${facility['name'] ?? 'Facility'}';
    final description = '${facility['description'] ?? ''}';
    final location = '${facility['location'] ?? 'Community facility'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shadowColor: navy.withValues(alpha: 0.10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 205,
                width: double.infinity,
                child: Image.network(
                  facilityPhoto(facility),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: pale,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 65,
                      color: navy,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF16855A),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Open for booking',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: ocean,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ocean,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => bookFacility(facility),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Book Now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget facilitiesPage() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [navy, ocean],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(height: 13),
                Text(
                  'Explore Our Facilities',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Enjoy thoughtfully designed spaces for work, wellness and community living.',
                  style: TextStyle(
                    color: pale,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Available Facilities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${items.length} community spaces',
            style: const TextStyle(color: ocean),
          ),
          const SizedBox(height: 17),
          ...items.map(facilityCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (busy) {
      content = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (failure != null) {
      content = RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: [
            const SizedBox(height: 90),
            const Center(child: Text('Error loading records')),
            Center(
              child: Text(
                failure!,
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (items.isEmpty) {
      content = RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Icon(
                Icons.inbox_outlined,
                size: 50,
                color: ocean,
              ),
            ),
            SizedBox(height: 12),
            Center(child: Text('No records yet')),
          ],
        ),
      );
    } else if (isFacilities && !widget.isAdmin) {
      content = facilitiesPage();
    } else {
      content = RefreshIndicator(
        onRefresh: load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (c, i) => record(items[i]),
        ),
      );
    }

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.isAdmin ? 'Facility Requests' : 'My Bookings',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.title),
      ),
      body: content,
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
    );
  }

  Widget repairPhotoPreview(
  String photoUrl, {
  String label = 'Attached Repair Photo',
}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
  label,
  style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: navy,
  ),
),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(20),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 900,
                        height: MediaQuery.sizeOf(dialogContext).height * 0.75,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Unable to load photo',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 420,
                height: 220,
                color: pale,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: ocean,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Photo unavailable',
                          style: TextStyle(color: ocean),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Row(
            children: [
              Icon(
                Icons.zoom_in,
                size: 17,
                color: ocean,
              ),
              SizedBox(width: 5),
              Text(
                'Tap photo to enlarge',
                style: TextStyle(
                  fontSize: 12,
                  color: ocean,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
   
  Widget vehicleInfoRow(
  IconData icon,
  String label,
  dynamic value,
) {
  final displayValue = value?.toString().trim() ?? '';

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: ocean),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue.isEmpty ? 'Not provided' : displayValue,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: navy,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget vehicleCard(Map<String, dynamic> x) {
  final photoUrl = x['photo_url']?.toString().trim() ?? '';

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: navy,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${x['plate_number'] ?? 'Unknown Plate'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Registered Vehicle',
                      style: TextStyle(
                        fontSize: 12,
                        color: ocean,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            'Vehicle Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),

          const SizedBox(height: 8),

          vehicleInfoRow(
            Icons.pin_outlined,
            'Plate Number',
            x['plate_number'],
          ),

          vehicleInfoRow(
            Icons.directions_car_outlined,
            'Vehicle Type',
            x['vehicle_type'],
          ),

          vehicleInfoRow(
            Icons.palette_outlined,
            'Color',
            x['color'],
          ),

          if (widget.isAdmin) ...[
            const Divider(height: 28),

            const Text(
              'Resident Information',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 8),

            vehicleInfoRow(
              Icons.person_outline,
              'Resident Name',
              x['full_name'],
            ),

            vehicleInfoRow(
              Icons.apartment_outlined,
              'Building',
              x['building'],
            ),

            vehicleInfoRow(
              Icons.home_outlined,
              'House / Unit Number',
              x['unit_number'],
            ),
          ],

          const Divider(height: 28),

          if (photoUrl.isNotEmpty)
            repairPhotoPreview(
              photoUrl,
              label: 'Attached Vehicle Photo',
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: pale,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.no_photography_outlined,
                    size: 36,
                    color: ocean,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No vehicle photo attached',
                    style: TextStyle(color: ocean),
                  ),
                ],
              ),
            ),

          if (!widget.isAdmin) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: actions(x),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget record(Map<String, dynamic> x) {
  if (path == '/vehicles/my' || path == '/admin/vehicles') {
    return vehicleCard(x);
  }

  final title =
        '${x['name'] ?? x['facility_name'] ?? x['service_name'] ?? x['title'] ?? x['subject'] ?? x['plate_number'] ?? x['courier'] ?? x['full_name'] ?? x['body'] ?? 'Record #${x['id']}'}';

    final status = x['status']?.toString();

    final details = x.entries
        .where(
          (e) =>
              ![
                'id',
                'user_id',
                'sender_id',
                'facility_id',
                'service_id',
                'name',
                'facility_name',
                'service_name',
                'title',
                'subject',
                'plate_number',
                'courier',
                'full_name',
                'body',
                'status',
                'password_hash',
                'photo_url',
                'created_at',
              ].contains(e.key) &&
              e.value != null,
        )
        .take(6)
        .map(
          (e) => '${e.key.replaceAll('_', ' ')}: ${e.value}',
        )
        .join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: navy,
                    ),
                  ),
                ),
                if (status != null)
                  Chip(
                    label: Text(status.replaceAll('_', ' ')),
                    backgroundColor: pale,
                  ),
              ],
            ),
            if (details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            if (x['description'] != null)
              Text(
                '${x['description']}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if ((path == '/admin/repairs' || path == '/repairs/my') &&
                x['photo_url'] != null &&
                x['photo_url'].toString().trim().isNotEmpty)
              repairPhotoPreview(
                x['photo_url'].toString().trim(),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: actions(x),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> actions(Map<String, dynamic> x) {
    final n = x['id'];
    final out = <Widget>[];

    Widget btn(String text, VoidCallback fn) =>
        OutlinedButton(onPressed: fn, child: Text(text));

    if (!widget.isAdmin) {
      if (path == '/facilities') {
        out.add(
          btn('Book', () => bookFacility(x)),
        );
      }

      if (path == '/services') {
        out.add(
          btn(
            'Request',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: '/service-requests/my',
                  user: widget.user,
                  selectedId: n,
                ),
              ),
            ).then((_) => load()),
          ),
        );
      }

      if (path == '/bookings/my' &&
          ['pending', 'approved'].contains(x['status'])) {
        out.add(
          btn(
            'Cancel',
            () => action('PUT', '/bookings/$n/cancel'),
          ),
        );
      }

      if (path == '/vehicles/my') {
        out.add(
          btn(
            'Edit',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: path,
                  user: widget.user,
                  existing: x,
                ),
              ),
            ).then((_) => load()),
          ),
        );

        out.add(
          btn('Delete', () => confirmDelete(n)),
        );
      }

      if (path == '/repairs/my' && x['status'] == 'pending') {
        out.add(
          btn(
            'Edit',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: path,
                  user: widget.user,
                  existing: x,
                ),
              ),
            ).then((_) => load()),
          ),
        );
      }
    } else {
      if (path == '/admin/residents' &&
          (x['approved'] == 0 || x['approved'] == false)) {
        out.add(
          btn(
            'Approve',
            () => action(
              'PUT',
              '/admin/residents/$n/approve',
            ),
          ),
        );
      }

      if (path == '/admin/bookings' && x['status'] == 'pending') {
        out.add(
          btn(
            'Approve',
            () => action(
              'PUT',
              '/admin/bookings/$n/status',
              {'status': 'approved'},
            ),
          ),
        );

        out.add(
          btn(
            'Reject',
            () => action(
              'PUT',
              '/admin/bookings/$n/status',
              {'status': 'rejected'},
            ),
          ),
        );
      }

      if (path == '/admin/repairs') {
        for (final s in [
          'in_progress',
          'completed',
          'rejected',
        ]) {
          if (x['status'] != s) {
            out.add(
              btn(
                s.replaceAll('_', ' '),
                () => action(
                  'PUT',
                  '/admin/repairs/$n/status',
                  {'status': s},
                ),
              ),
            );
          }
        }
      }

      if (path == '/admin/parcels' && x['status'] == 'arrived') {
        out.add(
          btn(
            'Mark collected',
            () => action(
              'PUT',
              '/admin/parcels/$n/collected',
            ),
          ),
        );
      }

      if (path == '/admin/bills') {
        out.add(
          btn(
            x['status'] == 'paid' ? 'Mark unpaid' : 'Mark paid',
            () => action(
              'PUT',
              '/admin/bills/$n/status',
              {
                'status': x['status'] == 'paid' ? 'unpaid' : 'paid',
              },
            ),
          ),
        );
      }

      if (path == '/admin/service-requests') {
        for (final s in [
          'accepted',
          'completed',
          'cancelled',
        ]) {
          if (x['status'] != s) {
            out.add(
              btn(
                s,
                () => action(
                  'PUT',
                  '/admin/service-requests/$n/status',
                  {'status': s},
                ),
              ),
            );
          }
        }
      }

      if (path == '/admin/suggestions') {
        out.add(
          btn(
            'Reply',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: '/admin/suggestions',
                  user: widget.user,
                  existing: x,
                ),
              ),
            ).then((_) => load()),
          ),
        );
      }

      if (path == '/admin/messages') {
        out.add(
          btn(
            'Reply',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: '/admin/messages',
                  user: widget.user,
                  existing: x,
                ),
              ),
            ).then((_) => load()),
          ),
        );
      }

      if (path == '/rules') {
        out.add(
          btn(
            'Edit',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  path: '/rules',
                  user: widget.user,
                  existing: x,
                ),
              ),
            ).then((_) => load()),
          ),
        );

        out.add(
          btn('Delete', () => confirmDelete(n)),
        );
      }
    }

    return out;
  }

  Future<void> confirmDelete(dynamic n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      action(
        'DELETE',
        path == '/rules' ? '/admin/rules/$n' : '/vehicles/$n',
      );
    }
  }
}
