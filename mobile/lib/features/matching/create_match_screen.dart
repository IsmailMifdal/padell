import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../booking/booking_providers.dart';
import 'matching_providers.dart';
import 'matching_repository.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  Club? _club;
  late DateTime _day;
  RangeValues _level = const RangeValues(2, 5);
  bool _private = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
  }

  Future<void> _create(Slot slot) async {
    setState(() => _busy = true);
    try {
      final match = await ref.read(matchingRepositoryProvider).create(
            courtId: slot.courtId,
            startsAt: slot.startsAt,
            durationMin: slot.durationMin,
            levelMin: _level.start,
            levelMax: _level.end,
            private: _private,
          );
      ref.invalidate(nearbyMatchesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match créé 🎾')),
        );
        context.pushReplacement('/matches/${match.id}');
      }
    } catch (e) {
      // Créneau plus disponible (verrou/réservation entre-temps) :
      // on recharge la grille pour retirer les créneaux fantômes.
      if (_club != null) {
        ref.invalidate(
          availabilityProvider((clubId: _club!.id, day: _day)),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubs = ref.watch(clubsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un match')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: PageContainer(
          maxWidth: 760,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _label('1 · Choisissez un club'),
            clubs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: CenteredLoader(),
              ),
              error: (e, _) => ErrorBanner(apiErrorMessage(e)),
              data: (list) => Column(
                children: list.map((c) {
                  final sel = _club?.id == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _club = c),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? AppColors.primary : AppColors.line,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: sel ? AppColors.primary : AppColors.slate,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(c.city,
                                        style: const TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_club != null) ...[
              const SizedBox(height: 18),
              _label('2 · Niveau des joueurs recherchés'),
              SoftCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Niveau ${_fmt(_level.start)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text('à ${_fmt(_level.end)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    RangeSlider(
                      values: _level,
                      min: 1,
                      max: 7,
                      divisions: 12,
                      activeColor: AppColors.primary,
                      labels: RangeLabels(_fmt(_level.start), _fmt(_level.end)),
                      onChanged: (v) => setState(() => _level = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _private,
                onChanged: (v) => setState(() => _private = v),
                title: const Text('Match privé',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Invisible dans la recherche — vos amis rejoignent via le lien de partage',
                  style: TextStyle(fontSize: 12),
                ),
                secondary: Icon(
                  _private ? Icons.lock_outline : Icons.public,
                  color: _private ? AppColors.amber : AppColors.slate,
                ),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
              ),
              const SizedBox(height: 14),
              _label('3 · Choisissez un créneau'),
              _DateStrip(
                selected: _day,
                onSelect: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 8),
              _Slots(
                clubId: _club!.id,
                day: _day,
                onPick: _create,
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Slots extends ConsumerWidget {
  const _Slots({required this.clubId, required this.day, required this.onPick});
  final String clubId;
  final DateTime day;
  final ValueChanged<Slot> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(availabilityProvider((clubId: clubId, day: day)));
    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: CenteredLoader(),
      ),
      error: (e, _) => ErrorBanner(apiErrorMessage(e)),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('Aucun créneau ce jour-là.',
                  style: TextStyle(color: AppColors.slate)),
            ),
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((s) {
            return GestureDetector(
              onTap: () => onPick(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: softShadow(0.04),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(s.startsAt),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      '${(s.priceMad / 4).toStringAsFixed(0)} MAD/pers.',
                      style: const TextStyle(
                          color: AppColors.slate, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelect});
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, i) {
          final d = DateTime(today.year, today.month, today.day + i);
          final isSel = d == selected;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
              decoration: BoxDecoration(
                gradient: isSel ? AppColors.heroGradient : null,
                color: isSel ? null : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: softShadow(0.04),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'AUJ' : DateFormat('E', 'fr').format(d).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
