import 'package:e_response_app_nemsu/controllers/VTextFieldController.dart';
import 'package:e_response_app_nemsu/helpers/maps_config.dart';
import 'package:e_response_app_nemsu/services/places_autocomplete_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

/// Address field with optional address suggestions (Tandag City): Google Places
/// when [MapsConfig.mapsApiKey] is set, otherwise OpenStreetMap Nominatim (no key).
/// The user can always type any address; suggestions are non-blocking hints.
class AddressSuggestionField extends StatelessWidget {
  const AddressSuggestionField({
    super.key,
    required this.controller,
    required this.hintText,
    this.headerText,
    this.textInputAction = TextInputAction.next,
    this.topPadding = 18,
    this.headerBottomSpacing = 8,
  });

  final VTextFieldController controller;
  final String hintText;
  final String? headerText;
  final TextInputAction textInputAction;
  final double topPadding;
  final double headerBottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerText != null)
            Padding(
              padding: EdgeInsets.only(bottom: headerBottomSpacing),
              child: Text(
                headerText!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          TypeAheadField<String>(
            controller: controller.textController,
            hideOnEmpty: true,
            hideOnError: true,
            debounceDuration: const Duration(milliseconds: 350),
            suggestionsCallback: (pattern) async {
              final p = pattern.trim();
              if (p.length < 2) {
                return <String>[];
              }
              return PlacesAutocompleteService.instance
                  .fetchTandagSuggestions(pattern);
            },
            builder: (context, textController, focusNode) {
              return TextField(
                controller: textController,
                focusNode: focusNode,
                keyboardType: TextInputType.streetAddress,
                textInputAction: textInputAction,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: theme.inputDecorationTheme.hintStyle,
                ),
              );
            },
            itemBuilder: (context, item) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.place_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: Text(
                  item,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            },
            onSelected: (value) {
              controller.textController.text = value;
              controller.textController.selection = TextSelection.collapsed(
                offset: value.length,
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            MapsConfig.hasMapsApiKey
                ? 'Suggestions use Google Places (Tandag area). '
                    'You can still type your complete address.'
                : 'Suggestions use OpenStreetMap (no API key). Type at least '
                    '2 characters (barangay / street). Tandag area only. '
                    'Data © OpenStreetMap contributors. You can still type freely.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
