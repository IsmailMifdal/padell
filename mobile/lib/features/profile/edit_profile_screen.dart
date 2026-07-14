import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import 'profile_repository.dart';

/// Édition du profil joueur : identité, ville, niveau, position, main.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _city = TextEditingController();
  double _level = 2.0;
  String? _position;
  String? _hand;
  String? _avatarUrl;
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _city.dispose();
    super.dispose();
  }

  void _hydrate(Me me) {
    if (_loaded) return;
    _loaded = true;
    _firstName.text = me.firstName;
    _lastName.text = me.lastName;
    _city.text = me.city ?? '';
    _level = me.level ?? 2.0;
    _position = me.courtPosition;
    _hand = me.handedness;
    _avatarUrl = me.avatarUrl;
  }

  /// Choix d'une photo → upload S3 présigné → URL publique.
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final contentType = picked.mimeType ?? 'image/jpeg';
      final url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(bytes, contentType);
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            city: _city.text.trim(),
            level: double.parse(_level.toStringAsFixed(1)),
            courtPosition: _position,
            handedness: _hand,
            avatarUrl: _avatarUrl,
          );
      ref.invalidate(meProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil de jeu')),
      body: me.when(
        loading: () => const CenteredLoader(),
        error: (e, _) => ErrorRetry(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(meProvider),
        ),
        data: (data) {
          _hydrate(data);
          return PageContainer(
            maxWidth: 560,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // Avatar (upload via URL présignée)
                Center(
                  child: GestureDetector(
                    onTap: _uploading ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: _avatarUrl == null
                              ? null
                              : NetworkImage(_avatarUrl!),
                          child: _uploading
                              ? const CircularProgressIndicator(strokeWidth: 2.5)
                              : _avatarUrl == null
                                  ? const Icon(Icons.person,
                                      size: 42, color: AppColors.primaryDark)
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstName,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastName,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Niveau de jeu'),
                SoftCard(
                  child: Column(
                    children: [
                      Text(
                        _level.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Slider(
                        value: _level,
                        min: 1,
                        max: 7,
                        divisions: 12,
                        activeColor: AppColors.primary,
                        label: _level.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _level = v),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Débutant',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.slate)),
                          Text('Compétition',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.slate)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Position préférée'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'LEFT', label: Text('Gauche')),
                    ButtonSegment(value: 'RIGHT', label: Text('Droite')),
                    ButtonSegment(value: 'BOTH', label: Text('Les deux')),
                  ],
                  selected: {_position ?? 'BOTH'},
                  onSelectionChanged: (s) =>
                      setState(() => _position = s.first),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Main'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'RIGHT', label: Text('Droitier')),
                    ButtonSegment(value: 'LEFT', label: Text('Gaucher')),
                  ],
                  selected: {_hand ?? 'RIGHT'},
                  onSelectionChanged: (s) => setState(() => _hand = s.first),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}
