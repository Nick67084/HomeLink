
part of '../../main.dart';

class RecordForm extends StatefulWidget {
  final String path;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? existing;
  final dynamic selectedId;

  const RecordForm({
    super.key,
    required this.path,
    required this.user,
    this.existing,
    this.selectedId,
  });

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final key = GlobalKey<FormState>();
  final inputs = <String, TextEditingController>{};

  bool saving = false;
  bool pickingImage = false;

  XFile? selectedPhoto;
  Uint8List? photoPreview;

  bool get isRepair => widget.path == '/repairs/my';

  List<String> get fields => switch (widget.path) {
        '/repairs/my' => [
            'title',
            'description',
          ],
        '/vehicles/my' => [
            'plate_number',
            'vehicle_type',
            'color',
          ],
        '/suggestions/my' => [
            'subject',
            'message',
          ],
        '/bookings/my' => [
            'start_at',
            'end_at',
          ],
        '/service-requests/my' => ['note'],
        '/messages/my' => ['body'],
        '/admin/parcels' => [
            'user_id',
            'courier',
            'tracking_number',
          ],
        '/admin/bills' => [
            'user_id',
            'title',
            'amount',
            'due_date',
          ],
        '/rules' => [
            'title',
            'content',
          ],
        '/admin/suggestions' => ['reply'],
        '/admin/messages' => ['body'],
        _ => [],
      };

  @override
  void initState() {
    super.initState();

    for (final field in fields) {
      inputs[field] = TextEditingController(
        text: '${widget.existing?[field] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> choosePhoto() async {
    if (pickingImage || saving) return;

    setState(() => pickingImage = true);

    try {
      final picker = ImagePicker();

      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();

      // Limit uploads to 5 MB.
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          toast(context, 'Please select an image under 5 MB.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          selectedPhoto = photo;
          photoPreview = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        toast(context, 'Could not select image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => pickingImage = false);
      }
    }
  }

  void removePhoto() {
    setState(() {
      selectedPhoto = null;
      photoPreview = null;
    });
  }

  Future<String> uploadRepairPhoto() async {
    if (selectedPhoto == null || photoPreview == null) {
      throw Exception('No photo selected');
    }

    final uri = Uri.parse('$apiBase/uploads/repair-photo');

    final request = http.MultipartRequest('POST', uri);

    if (Api.token != null) {
      request.headers['Authorization'] = 'Bearer ${Api.token}';
    }

    
final filename = selectedPhoto!.name;
final extension = filename.split('.').last.toLowerCase();

final mimeType = switch (extension) {
  'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
  'png' => MediaType('image', 'png'),
  'webp' => MediaType('image', 'webp'),
  _ => throw Exception(
      'Unsupported image format. Please choose JPG, PNG or WebP.',
    ),
};

request.files.add(
  http.MultipartFile.fromBytes(
    'photo',
    photoPreview!,
    filename: filename,
    contentType: mimeType,
  ),
);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    dynamic result;

    try {
      result = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Invalid upload response (${response.statusCode})',
      );
    }

    if (response.statusCode >= 400) {
      throw Exception(
        result is Map
            ? '${result['error'] ?? 'Photo upload failed'}'
            : 'Photo upload failed',
      );
    }

    if (result is! Map || result['url'] == null) {
      throw Exception('Upload response did not include a photo URL');
    }

    return '${result['url']}';
  }

  Future<void> submit() async {
    if (!key.currentState!.validate()) return;

    setState(() => saving = true);

    final data = <String, dynamic>{
      for (final entry in inputs.entries)
        entry.key: entry.value.text.trim(),
    };

    final existing = widget.existing;

    String method = 'POST';
    String endpoint = widget.path;

    if (widget.path == '/bookings/my') {
      endpoint = '/bookings';
      data['facility_id'] = '${widget.selectedId}';
    } else if (widget.path == '/service-requests/my') {
      endpoint = '/service-requests';
      data['service_id'] = '${widget.selectedId}';
    } else if (widget.path == '/admin/suggestions') {
      endpoint = '/admin/suggestions/${existing?['id']}/reply';
      method = 'PUT';
    } else if (widget.path == '/admin/messages') {
      endpoint = '/messages';
      data['user_id'] = '${existing?['user_id']}';
    } else if (widget.path == '/rules') {
      endpoint = '/admin/rules';

      if (existing != null) {
        method = 'PUT';
        endpoint += '/${existing['id']}';
      }
    } else if (widget.path.startsWith('/admin/')) {
      // Admin create routes use the existing endpoint.
    } else {
      endpoint = widget.path.replaceAll('/my', '');

      if (existing != null) {
        method = 'PUT';
        endpoint += '/${existing['id']}';
      }
    }

    try {
      if (isRepair) {
        // Keep the existing photo when editing a repair.
        String? photoUrl = existing?['photo_url']?.toString();

        // Upload a newly selected photo first.
        if (selectedPhoto != null) {
          photoUrl = await uploadRepairPhoto();
        }

        data['photo_url'] = photoUrl;
      }

      await Api.request(method, endpoint, data);

      if (mounted) {
        toast(context, 'Saved successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        toast(context, err(e));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> chooseDateTime(String field) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    inputs[field]?.text = selected.toIso8601String();

    setState(() {});
  }

  Future<void> chooseDueDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );

    if (date == null) return;

    inputs['due_date']?.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    setState(() {});
  }

  Widget repairPhotoPicker() {
    final existingPhoto = widget.existing?['photo_url']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repair Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Upload a photo of the issue (optional, maximum 5 MB).',
          style: TextStyle(
            color: ocean,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        if (photoPreview != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              photoPreview!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else if (existingPhoto != null &&
            existingPhoto.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              existingPhoto,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 100,
                child: Center(
                  child: Text('Photo preview unavailable'),
                ),
              ),
            ),
          )
        else
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: navy.withValues(alpha: 0.12),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: navy,
                ),
                SizedBox(height: 10),
                Text(
                  'No photo selected',
                  style: TextStyle(color: ocean),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickingImage || saving
                    ? null
                    : choosePhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  pickingImage
                      ? 'Opening gallery...'
                      : photoPreview == null
                          ? 'Choose Photo'
                          : 'Change Photo',
                ),
              ),
            ),
            if (photoPreview != null) ...[
              const SizedBox(width: 10),
              IconButton(
                onPressed: saving ? null : removePhoto,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove selected photo',
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'New Request'
              : 'Update Record',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: key,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Complete the information below',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 12),

              if (widget.path == '/bookings/my')
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Choose a future start and end time (maximum 4 hours).',
                  ),
                ),

              if (widget.path == '/admin/bills')
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Due date format: YYYY-MM-DD',
                  ),
                ),

              ...fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: inputs[field],
                    maxLines: [
                      'description',
                      'message',
                      'content',
                      'note',
                      'reply',
                      'body',
                    ].contains(field)
                        ? 4
                        : 1,
                    keyboardType: [
                      'amount',
                      'user_id',
                    ].contains(field)
                        ? TextInputType.number
                        : TextInputType.text,
                    readOnly: [
                      'start_at',
                      'end_at',
                      'due_date',
                    ].contains(field),
                    onTap: [
                      'start_at',
                      'end_at',
                    ].contains(field)
                        ? () => chooseDateTime(field)
                        : field == 'due_date'
                            ? chooseDueDate
                            : null,
                    decoration: InputDecoration(
                      labelText: field
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      suffixIcon: [
                        'start_at',
                        'end_at',
                        'due_date',
                      ].contains(field)
                          ? const Icon(
                              Icons.calendar_today_outlined,
                            )
                          : null,
                    ),
                    validator: (value) {
                      if ([
                        'color',
                        'tracking_number',
                        'note',
                      ].contains(field)) {
                        return null;
                      }

                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Required';
                      }

                      return null;
                    },
                  ),
                ),
              ),

              if (isRepair) repairPhotoPicker(),

              const SizedBox(height: 12),

              FilledButton(
                onPressed: saving ? null : submit,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    saving ? 'Saving...' : 'Submit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
