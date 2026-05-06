import 'dart:io';

import 'package:e_response_app_nemsu/controllers/message_report_controller.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/location_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/report_page/message_report_submitted_screen.dart';
import 'package:e_response_app_nemsu/views/components/VButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

const int _kMaxReportImages = 8;
const int _kMinDetailsLength = 8;

class MessageReportScreen extends StatefulWidget {
  const MessageReportScreen({super.key});

  @override
  State<MessageReportScreen> createState() => _MessageReportScreenState();
}

class _MessageReportScreenState extends State<MessageReportScreen> {
  final MessageReportController _controller = MessageReportController();
  final TextEditingController _locationController = TextEditingController();
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  String? _userId;
  String? _bearerToken;
  bool _bootstrapLoading = true;
  bool _submitting = false;
  bool _resolvingLocation = false;
  String _locationStatus = '';

  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndInitialize();
    _setCurrentLocation();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _setCurrentLocation() async {
    setState(() {
      _resolvingLocation = true;
      _locationStatus = 'Locating you…';
    });
    try {
      final currentAddress = await LocationService.getCurrentAddress();
      await _controller.getLocationDetails(currentAddress);
      if (!mounted) return;
      setState(() {
        _locationController.text = currentAddress;
        _locationStatus = 'Location ready';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Could not auto-detect location — enter it below.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= _kMaxReportImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can attach up to $_kMaxReportImages photos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images == null || images.isEmpty) return;
      setState(() {
        final remaining = _kMaxReportImages - _selectedImages.length;
        _selectedImages.addAll(images.take(remaining));
        if (images.length > remaining) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only $remaining more photo(s) added (max $_kMaxReportImages).',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add photos: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadCredentialsAndInitialize() async {
    try {
      await _controller.initialize();
      final credentials = await _prefsService.getCredentials();
      if (!mounted) return;
      setState(() {
        _userId = credentials['id'];
        _bearerToken = credentials['token'];
        _bootstrapLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userId = null;
        _bearerToken = null;
        _bootstrapLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your session: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onSuggestionSelected(String suggestion) async {
    setState(() => _locationStatus = 'Resolving address…');
    _locationController.text = suggestion;
    try {
      await _controller.getLocationDetails(suggestion);
      if (!mounted) return;
      setState(() => _locationStatus = 'Location coordinates ready');
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationStatus = 'Could not resolve that address — try another.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_userId == null) return;
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the incident location.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_controller.detailsController.text.trim().length < _kMinDetailsLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least $_kMinDetailsLength characters describing what happened.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final result = await _controller.submitReport(
      locationText: _locationController.text,
      userId: _userId!,
      images: List<XFile>.from(_selectedImages),
      bearerToken: _bearerToken,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _controller.clearAfterSuccess();
      setState(() => _selectedImages.clear());
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MessageReportSubmittedScreen(
            referenceLabel: result.reference,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  bool get _canSubmit =>
      _userId != null &&
      !_bootstrapLoading &&
      !_submitting &&
      _locationController.text.trim().isNotEmpty &&
      _controller.detailsController.text.trim().length >= _kMinDetailsLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Message report'),
      ),
      body: _bootstrapLoading
          ? _buildShimmer()
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_userId == null)
                            _NoticeCard(
                              icon: Icons.login_rounded,
                              text:
                                  'You need to be signed in to submit a report. Open Profile or log in again.',
                              color: AppColors.warning,
                            )
                          else
                            _NoticeCard(
                              icon: Icons.info_outline_rounded,
                              text:
                                  'Describe what happened and where. Photos are optional. '
                                  'Submitting does not automatically dispatch an ambulance — '
                                  'CDRRMO will use this according to their procedures.',
                              color: AppColors.primary,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Where did it happen?',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TypeAheadField<String>(
                            controller: _locationController,
                            suggestionsCallback: (query) =>
                                _controller.getSuggestions(query),
                            builder: (context, textController, focusNode) {
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                onChanged: (_) => setState(() {}),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  hintText: 'Search or edit incident location…',
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon: _resolvingLocation
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: 'Refresh GPS location',
                                          icon: const Icon(Icons.my_location),
                                          onPressed: _resolvingLocation
                                              ? null
                                              : _setCurrentLocation,
                                        ),
                                  hintStyle: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              );
                            },
                            itemBuilder: (context, suggestion) => ListTile(
                              leading: const Icon(Icons.place_outlined, size: 20),
                              title: Text(
                                suggestion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onSelected: _onSuggestionSelected,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _locationStatus,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'What happened?',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controller.detailsController,
                            onChanged: (_) => setState(() {}),
                            minLines: 5,
                            maxLines: 10,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              alignLabelWithHint: true,
                              hintText:
                                  'Who, what, when, and any injuries or hazards (min. $_kMinDetailsLength characters).',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              counterText:
                                  '${_controller.detailsController.text.trim().length} chars '
                                  '(min $_kMinDetailsLength)',
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                'Photos (optional)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedImages.length}/$_kMaxReportImages',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 88,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ...List.generate(_selectedImages.length, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            File(_selectedImages[i].path),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: Material(
                                            color: AppColors.accent,
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () => _removeImage(i),
                                              child: const Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Material(
                                  color: AppColors.backgroundAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: _pickImages,
                                    borderRadius: BorderRadius.circular(10),
                                    child: const SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          VButton(
                            text: 'Send to CDRRMO',
                            isLoading: _submitting,
                            onPressed: _canSubmit ? _submit : () {},
                            backgroundColor:
                                _canSubmit ? null : AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'By sending, you confirm the information is accurate to the best of your knowledge.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: AppColors.skeletonBase,
        highlightColor: AppColors.skeletonHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
