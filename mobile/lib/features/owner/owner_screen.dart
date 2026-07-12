import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import 'owner_repository.dart';

/// Liste des clubs du propriétaire.
class OwnerScreen extends ConsumerWidget {
  const OwnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myClubsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Espace club')),
      body: PageContainer(
        maxWidth: 720,
        child: clubs.when(
          loading: () => const CenteredLoader(),
          error: (e, _) => ErrorRetry(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(myClubsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.stadium_outlined,
                title: 'Aucun club',
                subtitle: 'Votre club apparaîtra ici une fois créé.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final c = list[i];
                final approved = c.status == 'APPROVED';
                return SoftCard(
                  onTap: approved
                      ? () => context.push('/owner/club', extra: c)
                      : null,
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.coverFor(c.id),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            const Icon(Icons.stadium, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                              '${c.city} · ${c.courts.length} terrain(s)',
                              style: const TextStyle(
                                  color: AppColors.slate, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      InfoChip(
                        label: approved ? 'Validé' : c.status,
                        color: approved ? AppColors.primary : AppColors.amber,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Gestion opérationnelle d'un club : calendrier + actions.
class OwnerClubScreen extends ConsumerStatefulWidget {
  const OwnerClubScreen({super.key, required this.club});
  final OwnerClub club;

  @override
  ConsumerState<OwnerClubScreen> createState() => _OwnerClubScreenState();
}

class _OwnerClubScreenState extends ConsumerState<OwnerClubScreen> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
  }

  OwnerCalendarArgs get _args => (clubId: widget.club.id, day: _day);

  void _refresh() => ref.invalidate(ownerCalendarProvider(_args));

  Future<void> _snack(String msg) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _manualBooking() async {
    final result = await showDialog<_SlotForm>(
      context: context,
      builder: (ctx) => _SlotFormDialog(
        title: 'Réservation manuelle',
        courts: widget.club.courts,
        askPrice: true,
        askName: true,
      ),
    );
    if (result == null) return;
    try {
      await ref.read(ownerRepositoryProvider).manualBooking(
            widget.club.id,
            courtId: result.courtId,
            startsAt: DateTime(_day.year, _day.month, _day.day, result.hour,
                result.minute),
            durationMin: result.durationMin,
            priceMad: result.price,
            customerName: result.name,
          );
      _refresh();
      _snack('Réservation ajoutée ✅');
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _blockSlot() async {
    final result = await showDialog<_SlotForm>(
      context: context,
      builder: (ctx) => _SlotFormDialog(
        title: 'Bloquer un créneau',
        courts: widget.club.courts,
        askReason: true,
      ),
    );
    if (result == null) return;
    try {
      await ref.read(ownerRepositoryProvider).blockSlot(
            widget.club.id,
            courtId: result.courtId,
            startsAt: DateTime(_day.year, _day.month, _day.day, result.hour,
                result.minute),
            durationMin: result.durationMin,
            reason: result.name,
          );
      _refresh();
      _snack('Créneau bloqué ✅');
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _checkin() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Check-in client'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Code QR de la réservation',
            prefixIcon: Icon(Icons.qr_code_2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final court =
          await ref.read(ownerRepositoryProvider).checkin(widget.club.id, code);
      _refresh();
      _snack('Check-in validé — $court ✅');
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  Future<void> _cancel(OwnerBooking b) async {
    try {
      await ref.read(ownerRepositoryProvider).cancelBooking(widget.club.id, b.id);
      _refresh();
      _snack('Réservation annulée');
    } catch (e) {
      _snack(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(ownerCalendarProvider(_args));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.club.name),
        actions: [
          IconButton(
            tooltip: 'Statistiques',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => _StatsSheet(clubId: widget.club.id),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ActionsSheet(
            onManual: _manualBooking,
            onBlock: _blockSlot,
            onCheckin: _checkin,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Actions'),
      ),
      body: PageContainer(
        maxWidth: 860,
        child: Column(
          children: [
            SizedBox(
              height: 82,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: 14,
                itemBuilder: (context, i) {
                  final today = DateTime.now();
                  final d =
                      DateTime(today.year, today.month, today.day + i);
                  final isSel = d == _day;
                  return GestureDetector(
                    onTap: () => setState(() => _day = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 58,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        gradient: isSel ? AppColors.heroGradient : null,
                        color: isSel
                            ? null
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: softShadow(isSel ? 0.12 : 0.04),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            i == 0
                                ? 'AUJ'
                                : DateFormat('E', 'fr')
                                    .format(d)
                                    .toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSel ? Colors.white : AppColors.slate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 19,
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
            ),
            Expanded(
              child: calendar.when(
                loading: () => const CenteredLoader(),
                error: (e, _) => ErrorRetry(
                  message: apiErrorMessage(e),
                  onRetry: _refresh,
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'Aucune réservation ce jour',
                      subtitle:
                          'Utilisez « Actions » pour ajouter une réservation\nou bloquer un créneau.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _bookingTile(list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingTile(OwnerBooking b) {
    final isBlocked = b.source == 'BLOCKED';
    final color = isBlocked
        ? AppColors.slate
        : b.status == 'COMPLETED'
            ? AppColors.info
            : b.status == 'PENDING_PAYMENT'
                ? AppColors.amber
                : AppColors.primary;
    final label = isBlocked
        ? 'Bloqué'
        : b.status == 'COMPLETED'
            ? 'Check-in fait'
            : b.status == 'PENDING_PAYMENT'
                ? 'À payer'
                : b.source == 'MANUAL'
                    ? 'Manuelle'
                    : b.matchId != null
                        ? 'Match'
                        : 'Confirmée';

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('HH:mm').format(b.startsAt)} – '
                  '${DateFormat('HH:mm').format(b.endsAt)} · ${b.courtName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  b.customer ?? b.note ?? (isBlocked ? 'Indisponible' : '—'),
                  style:
                      const TextStyle(color: AppColors.slate, fontSize: 13),
                ),
              ],
            ),
          ),
          InfoChip(label: label, color: color),
          if (b.status == 'CONFIRMED' || b.status == 'PENDING_PAYMENT')
            IconButton(
              tooltip: 'Annuler',
              onPressed: () => _cancel(b),
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

/// Statistiques d'exploitation (30 jours) : réservations, revenus, heures.
class _StatsSheet extends ConsumerWidget {
  const _StatsSheet({required this.clubId});
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(ownerStatsProvider(clubId));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: stats.when(
        loading: () => const SizedBox(height: 220, child: CenteredLoader()),
        error: (e, _) => SizedBox(
          height: 200,
          child: ErrorRetry(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(ownerStatsProvider(clubId)),
          ),
        ),
        data: (s) {
          final maxCount = s.byHour.values.isEmpty
              ? 1
              : s.byHour.values.reduce((a, b) => a > b ? a : b);
          final hours = s.byHour.keys.toList()..sort();
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 5,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Activité — ${s.days} derniers jours',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _kpi('Réservations', '${s.totalBookings}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _kpi('Revenus',
                            '${s.revenueMad.toStringAsFixed(0)} MAD')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _kpi('Annulations', '${s.cancelledBookings}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _kpi('Résas manuelles', '${s.manualShare} %')),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Réservations par heure',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (hours.isEmpty)
                  const Text('Pas encore de données.',
                      style: TextStyle(color: AppColors.slate))
                else
                  ...hours.map((h) {
                    final count = s.byHour[h]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}h',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.slate),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: count / maxCount,
                                minHeight: 10,
                                backgroundColor: AppColors.line,
                                valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$count',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.slate)),
          ],
        ),
      );
}

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet({
    required this.onManual,
    required this.onBlock,
    required this.onCheckin,
  });

  final VoidCallback onManual;
  final VoidCallback onBlock;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback action) => ListTile(
          leading: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 20),
          ),
          title: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            action();
          },
        );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.edit_calendar_outlined, 'Réservation manuelle', onManual),
          item(Icons.block_outlined, 'Bloquer un créneau', onBlock),
          item(Icons.qr_code_scanner, 'Check-in client (QR)', onCheckin),
        ],
      ),
    );
  }
}

class _SlotForm {
  _SlotForm({
    required this.courtId,
    required this.hour,
    required this.minute,
    required this.durationMin,
    this.price,
    this.name,
  });

  final String courtId;
  final int hour;
  final int minute;
  final int durationMin;
  final double? price;
  final String? name;
}

/// Formulaire commun résa manuelle / blocage : terrain + heure + durée.
class _SlotFormDialog extends StatefulWidget {
  const _SlotFormDialog({
    required this.title,
    required this.courts,
    this.askPrice = false,
    this.askName = false,
    this.askReason = false,
  });

  final String title;
  final List<OwnerCourt> courts;
  final bool askPrice;
  final bool askName;
  final bool askReason;

  @override
  State<_SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<_SlotFormDialog> {
  late String _courtId;
  final _time = TextEditingController(text: '18:00');
  final _price = TextEditingController();
  final _name = TextEditingController();
  int _duration = 90;
  String? _error;

  @override
  void initState() {
    super.initState();
    _courtId = widget.courts.first.id;
  }

  @override
  void dispose() {
    _time.dispose();
    _price.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_time.text.trim());
    if (m == null) {
      setState(() => _error = 'Heure attendue au format HH:MM');
      return;
    }
    final hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    if (hour > 23 || minute > 59) {
      setState(() => _error = 'Heure invalide');
      return;
    }
    Navigator.pop(
      context,
      _SlotForm(
        courtId: _courtId,
        hour: hour,
        minute: minute,
        durationMin: _duration,
        price: double.tryParse(_price.text.trim()),
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            DropdownButtonFormField<String>(
              initialValue: _courtId,
              decoration: const InputDecoration(labelText: 'Terrain'),
              items: widget.courts
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _courtId = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _time,
              decoration: const InputDecoration(
                labelText: 'Heure de début',
                hintText: '18:00',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Durée'),
              items: const [60, 90, 120, 180]
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text('$d min')))
                  .toList(),
              onChanged: (v) => setState(() => _duration = v!),
            ),
            if (widget.askPrice) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Prix (MAD, optionnel)'),
              ),
            ],
            if (widget.askName || widget.askReason) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText:
                      widget.askName ? 'Nom du client (optionnel)' : 'Motif',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }
}
