import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import '../profile/profile_repository.dart';
import 'owner_repository.dart';

const _amenityChoices = [
  'parking',
  'douches',
  'vestiaires',
  'cafétéria',
  'location de matériel',
  'wifi',
];

/// Devenir partenaire : déposer son club (validé ensuite par l'équipe).
class CreateClubScreen extends ConsumerStatefulWidget {
  const CreateClubScreen({super.key});

  @override
  ConsumerState<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends ConsumerState<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final Set<String> _amenities = {};
  bool _onSite = true;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _description, _address, _city, _phone, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Remplit lat/lng avec la position actuelle (le gérant est sur place).
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Position indisponible — saisissez-la manuellement')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(ownerRepositoryProvider).createClub(
            name: _name.text.trim(),
            description: _description.text.trim(),
            address: _address.text.trim(),
            city: _city.text.trim(),
            phone: _phone.text.trim(),
            latitude: double.parse(_lat.text.trim()),
            longitude: double.parse(_lng.text.trim()),
            amenities: _amenities.toList(),
            paymentOnSiteAllowed: _onSite,
          );
      // Le rôle OWNER vient d'être attribué : rafraîchir profil + clubs
      ref.invalidate(meProvider);
      ref.invalidate(myClubsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Club envoyé ✅ — il sera visible après validation par notre équipe'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ requis' : null;

  String? _coord(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ requis';
    return double.tryParse(v.trim()) == null ? 'Nombre invalide' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter mon club')),
      body: PageContainer(
        maxWidth: 620,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              // Bandeau devenir partenaire
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Text('🏟️', style: TextStyle(fontSize: 30)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Référencez votre club : votre demande est examinée '
                        'par notre équipe avant publication.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ErrorBanner(_error!),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom du club',
                  prefixIcon: Icon(Icons.stadium_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Téléphone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Position sur la carte',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Latitude'),
                      validator: _coord,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Longitude'),
                      validator: _coord,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Utiliser ma position (je suis au club)'),
              ),
              const SizedBox(height: 18),
              const Text('Équipements',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amenityChoices
                    .map(
                      (a) => FilterChip(
                        label: Text(a),
                        selected: _amenities.contains(a),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.18),
                        onSelected: (v) => setState(
                            () => v ? _amenities.add(a) : _amenities.remove(a)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _onSite,
                onChanged: (v) => setState(() => _onSite = v),
                title: const Text('Accepter le paiement sur place'),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Envoyer ma demande'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
