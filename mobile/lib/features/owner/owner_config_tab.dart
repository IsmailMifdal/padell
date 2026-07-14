import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../shared/widgets.dart';
import 'owner_repository.dart';

const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String _minToHHMM(int min) =>
    '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

int? _parseHHMM(String v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final mn = int.parse(m.group(2)!);
  if (h > 24 || mn > 59) return null;
  return h * 60 + mn;
}

/// Configuration du club : terrains, horaires d'ouverture, règles tarifaires.
/// Les données fraîches viennent de myClubsProvider (rafraîchi après chaque action).
class OwnerConfigTab extends ConsumerWidget {
  const OwnerConfigTab({super.key, required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myClubsProvider);
    return clubs.when(
      loading: () => const CenteredLoader(),
      error: (e, _) => ErrorRetry(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(myClubsProvider),
      ),
      data: (list) {
        final club = list.where((c) => c.id == clubId).firstOrNull;
        if (club == null) {
          return const EmptyState(
            icon: Icons.stadium_outlined,
            title: 'Club introuvable',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            if (club.status != 'APPROVED') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, color: AppColors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'En attente de validation — préparez vos terrains, '
                        'horaires et tarifs : tout sera prêt à la publication.',
                        style: TextStyle(
                            color: Color(0xFF92600A),
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            _CourtsSection(club: club),
            const SizedBox(height: 24),
            _HoursSection(club: club),
            const SizedBox(height: 24),
            _PricingSection(club: club),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ terrains

class _CourtsSection extends ConsumerWidget {
  const _CourtsSection({required this.club});
  final OwnerClub club;

  static const _typeLabels = {
    'INDOOR': 'Couvert',
    'OUTDOOR': 'Extérieur',
    'PANORAMIC': 'Panoramique',
  };

  Future<void> _addCourt(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(
        text: 'Terrain ${club.courts.length + 1}');
    var type = 'OUTDOOR';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter un terrain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _typeLabels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ref
          .read(ownerRepositoryProvider)
          .addCourt(club.id, name: name.text.trim(), type: type);
      ref.invalidate(myClubsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Terrains',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            TextButton.icon(
              onPressed: () => _addCourt(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Terrain'),
            ),
          ],
        ),
        if (club.courts.isEmpty)
          const Text('Ajoutez votre premier terrain pour définir des tarifs.',
              style: TextStyle(color: AppColors.slate, fontSize: 13)),
        ...club.courts.map(
          (c) => SoftCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sports_tennis,
                      size: 20, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${_typeLabels[c.type] ?? c.type} · ${c.rules.length} règle(s) tarifaire(s)',
                        style: const TextStyle(
                            color: AppColors.slate, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ horaires

class _HoursSection extends ConsumerStatefulWidget {
  const _HoursSection({required this.club});
  final OwnerClub club;

  @override
  ConsumerState<_HoursSection> createState() => _HoursSectionState();
}

class _HoursSectionState extends ConsumerState<_HoursSection> {
  late final Map<int, bool> _open = {};
  late final Map<int, TextEditingController> _from = {};
  late final Map<int, TextEditingController> _to = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (var d = 1; d <= 7; d++) {
      final existing =
          widget.club.openingHours.where((h) => h.dayOfWeek == d).firstOrNull;
      _open[d] = existing != null;
      _from[d] =
          TextEditingController(text: _minToHHMM(existing?.openMin ?? 480));
      _to[d] =
          TextEditingController(text: _minToHHMM(existing?.closeMin ?? 1380));
    }
  }

  @override
  void dispose() {
    for (var d = 1; d <= 7; d++) {
      _from[d]!.dispose();
      _to[d]!.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final hours = <OpeningHour>[];
    for (var d = 1; d <= 7; d++) {
      if (_open[d] != true) continue;
      final from = _parseHHMM(_from[d]!.text);
      final to = _parseHHMM(_to[d]!.text);
      if (from == null || to == null || to <= from) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${_dayNames[d - 1]} : heures invalides (HH:MM)')),
        );
        return;
      }
      hours.add(OpeningHour(dayOfWeek: d, openMin: from, closeMin: to));
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .setOpeningHours(widget.club.id, hours);
      ref.invalidate(myClubsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horaires enregistrés ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horaires d’ouverture',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SoftCard(
          child: Column(
            children: [
              for (var d = 1; d <= 7; d++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(_dayNames[d - 1],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: _open[d]!,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) => setState(() => _open[d] = v),
                      ),
                      const SizedBox(width: 8),
                      if (_open[d]!) ...[
                        Expanded(
                          child: TextField(
                            controller: _from[d],
                            decoration: const InputDecoration(
                                isDense: true, labelText: 'Ouverture'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _to[d],
                            decoration: const InputDecoration(
                                isDense: true, labelText: 'Fermeture'),
                          ),
                        ),
                      ] else
                        const Expanded(
                          child: Text('Fermé',
                              style: TextStyle(color: AppColors.slate)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                child: Text(_saving ? '…' : 'Enregistrer les horaires'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- tarifs

class _PricingSection extends ConsumerWidget {
  const _PricingSection({required this.club});
  final OwnerClub club;

  Future<void> _addRule(
      BuildContext context, WidgetRef ref, OwnerCourt court) async {
    final start = TextEditingController(text: '08:00');
    final end = TextEditingController(text: '23:00');
    final price = TextEditingController(text: '300');
    var duration = 90;
    var allDays = true;
    var day = 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Tarif — ${court.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: allDays,
                  onChanged: (v) => setState(() => allDays = v ?? true),
                  title: const Text('Tous les jours'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!allDays)
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    decoration: const InputDecoration(labelText: 'Jour'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(
                            value: d, child: Text(_dayNames[d - 1])),
                    ],
                    onChanged: (v) => setState(() => day = v!),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: start,
                        decoration: const InputDecoration(labelText: 'De'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: end,
                        decoration: const InputDecoration(labelText: 'À'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration:
                      const InputDecoration(labelText: 'Durée du créneau'),
                  items: const [60, 90, 120]
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text('$d min')))
                      .toList(),
                  onChanged: (v) => setState(() => duration = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Prix du créneau (MAD)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final startMin = _parseHHMM(start.text);
    final endMin = _parseHHMM(end.text);
    final priceMad = double.tryParse(price.text.trim());
    if (startMin == null || endMin == null || endMin <= startMin ||
        priceMad == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valeurs invalides (heures HH:MM, prix)')),
        );
      }
      return;
    }

    final repo = ref.read(ownerRepositoryProvider);
    final days = allDays ? [1, 2, 3, 4, 5, 6, 7] : [day];
    try {
      for (final d in days) {
        await repo.addPricingRule(
          club.id,
          court.id,
          dayOfWeek: d,
          startMin: startMin,
          endMin: endMin,
          durationMin: duration,
          priceMad: priceMad,
        );
      }
      ref.invalidate(myClubsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
      ref.invalidate(myClubsProvider);
    }
  }

  Future<void> _deleteRule(
      BuildContext context, WidgetRef ref, PricingRule rule) async {
    try {
      await ref.read(ownerRepositoryProvider).deletePricingRule(club.id, rule.id);
      ref.invalidate(myClubsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tarifs & créneaux',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Les créneaux réservables sont générés à partir de ces règles.',
          style: TextStyle(color: AppColors.slate, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (club.courts.isEmpty)
          const Text('Ajoutez d’abord un terrain.',
              style: TextStyle(color: AppColors.slate, fontSize: 13)),
        ...club.courts.map(
          (court) => SoftCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(court.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      onPressed: () => _addRule(context, ref, court),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Règle'),
                    ),
                  ],
                ),
                if (court.rules.isEmpty)
                  const Text('Aucune règle — le terrain n’est pas réservable.',
                      style:
                          TextStyle(color: AppColors.slate, fontSize: 12)),
                ...court.rules.map(
                  (r) => Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(_dayNames[r.dayOfWeek - 1],
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Text(
                          '${_minToHHMM(r.startMin)}–${_minToHHMM(r.endMin)} · ${r.durationMin} min · ${r.priceMad.toStringAsFixed(0)} MAD',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        onPressed: () => _deleteRule(context, ref, r),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
