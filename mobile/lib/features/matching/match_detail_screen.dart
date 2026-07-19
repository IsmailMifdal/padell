import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/models.dart';
import '../../shared/payment_dialog.dart';
import '../../shared/payments_api.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'matching_providers.dart';
import 'matching_repository.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(matchDetailProvider(widget.matchId));
      ref.invalidate(nearbyMatchesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(okMsg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Crée la session CMI de sa part puis ouvre la feuille de paiement
  /// (finalisable par simulation en développement).
  Future<void> _payShare(PadelMatch m) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(paymentsApiProvider);
      final paid = await showPaymentSheet(
        context: context,
        api: api,
        amountMad: m.pricePerPlayerMad,
        createSession: () => api.matchSession(m.id),
      );
      if (paid) {
        ref.invalidate(matchDetailProvider(m.id));
        ref.invalidate(nearbyMatchesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Part payée ✅')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Partage du match : message + lien direct vers sa page.
  Future<void> _share(PadelMatch m) async {
    final when = DateFormat('EEEE d MMMM à HH:mm', 'fr').format(m.startsAt);
    final url = Uri.base.origin.isEmpty
        ? 'https://padel.ma/matches/${m.id}'
        : '${Uri.base.origin}/#/matches/${m.id}';
    await Share.share(
      '🎾 Rejoins-moi au padel !\n'
      '${m.clubName} (${m.city}) · $when\n'
      'Niveau ${m.levelMin.toStringAsFixed(0)}-${m.levelMax.toStringAsFixed(0)} · '
      '${m.pricePerPlayerMad.toStringAsFixed(0)} MAD/joueur · '
      '${m.spotsLeft} place(s) restante(s)\n$url',
      subject: 'Match de padel — ${m.clubName}',
    );
  }

  /// Saisie du score par l'organisateur : 2 vainqueurs + score.
  Future<void> _submitScore(PadelMatch m) async {
    final accepted = m.players.where((p) => p.status == 'ACCEPTED').toList();
    final result = await showDialog<({List<String> winners, String score})>(
      context: context,
      builder: (ctx) => _ScoreDialog(players: accepted),
    );
    if (result == null) return;
    await _run(
      () => ref.read(matchingRepositoryProvider).submitScore(
            m.id,
            winnerIds: result.winners,
            score: result.score,
          ),
      'Score enregistré 🏆 — les niveaux ont été mis à jour',
    );
  }

  /// Notation des partenaires (match joué).
  Future<void> _ratePlayers(PadelMatch m, List<String> alreadyRated) async {
    final myId = ref.read(authControllerProvider).user?.id;
    final toRate = m.players
        .where((p) =>
            p.status == 'ACCEPTED' &&
            p.playerId != myId &&
            !alreadyRated.contains(p.playerId))
        .toList();
    if (toRate.isEmpty) return;

    final items = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RatingSheet(players: toRate),
    );
    if (items == null || items.isEmpty) return;
    await _run(
      () => ref.read(matchingRepositoryProvider).ratePlayers(m.id, items),
      'Merci pour vos notes ⭐',
    );
    ref.invalidate(myRatingsProvider(m.id));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(matchDetailProvider(widget.matchId));
    final myId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du match'),
        actions: [
          // Inviter des amis (WhatsApp / Web Share / presse-papiers)
          IconButton(
            tooltip: 'Inviter',
            icon: const Icon(Icons.share_outlined),
            onPressed: async.valueOrNull == null
                ? null
                : () => _share(async.valueOrNull!),
          ),
        ],
      ),
      body: async.when(
        loading: () => const CenteredLoader(),
        error: (e, _) => ErrorRetry(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(matchDetailProvider(widget.matchId)),
        ),
        data: (m) => PageContainer(
          maxWidth: 760,
          child: _content(context, m, myId),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PadelMatch m, String? myId) {
    final isCreator = myId != null && m.creatorId == myId;
    final mine = m.players.where((p) => p.playerId == myId).toList();
    final myStatus = mine.isEmpty ? null : mine.first.status;
    final accepted = m.players.where((p) => p.status == 'ACCEPTED').toList();
    final requested = m.players.where((p) => p.status == 'REQUESTED').toList();
    final isParticipant = isCreator || myStatus == 'ACCEPTED';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Bandeau
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.coverFor(m.id),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.clubName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE d MMMM · HH:mm', 'fr')
                              .format(m.startsAt),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _glass('Niveau ${_lvl(m.levelMin)}–${_lvl(m.levelMax)}'),
                        _glass('${m.durationMin} min'),
                        _glass('${m.pricePerPlayerMad.toStringAsFixed(0)} MAD/pers.'),
                        if (m.visibility == 'PRIVATE') _glass('🔒 Privé'),
                      ],
                    ),
                  ],
                ),
              ),
              // Match joué : score + notation des partenaires
              if (m.status == 'PLAYED') ...[
                const SizedBox(height: 14),
                _scoreCard(m),
                if (isParticipant) _rateSection(m),
              ],
              // Accès chat pour les participants
              if (isParticipant) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.push('/matches/${m.id}/chat'),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Ouvrir le chat du match'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Joueurs',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${accepted.length}/${PadelMatch.size}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...accepted.map((p) => _playerRow(p, isCreatorId: m.creatorId)),
              for (int i = 0; i < m.spotsLeft; i++) _emptySlot(),
              // Demandes en attente : visibles par l'organisateur
              if (isCreator && requested.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Demandes en attente (${requested.length})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...requested.map((p) => _requestRow(m, p)),
              ],
            ],
          ),
        ),
        _actionBar(context, m, isCreator, myStatus),
      ],
    );
  }

  Widget _actionBar(
    BuildContext context,
    PadelMatch m,
    bool isCreator,
    String? myStatus,
  ) {
    final repo = ref.read(matchingRepositoryProvider);
    final isAcceptedMember = isCreator || myStatus == 'ACCEPTED';
    final myId = ref.read(authControllerProvider).user?.id;
    final iPaid = m.players
        .any((p) => p.playerId == myId && p.hasPaid);

    Widget primary;
    if (isCreator) {
      primary = _banner(
        Icons.verified_user,
        'Vous êtes l’organisateur de ce match.',
        AppColors.primary,
      );
    } else if (myStatus == 'ACCEPTED') {
      primary = OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() => repo.withdraw(m.id), 'Vous vous êtes désisté'),
        icon: const Icon(Icons.logout),
        label: const Text('Se désister'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else if (myStatus == 'REQUESTED') {
      primary = _banner(
        Icons.hourglass_top,
        'Demande envoyée — en attente de l’organisateur.',
        AppColors.amber,
      );
    } else if (m.spotsLeft == 0) {
      primary = _banner(Icons.block, 'Ce match est complet.', AppColors.slate);
    } else {
      primary = FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() => repo.join(m.id), 'Demande envoyée à l’organisateur'),
        icon: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('Rejoindre ce match'),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: softShadow(0.08),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paiement de sa part (créateur inclus) tant que le match est ouvert
          if (isAcceptedMember &&
              !iPaid &&
              (m.status == 'OPEN' || m.status == 'FULL')) ...[
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _payShare(m),
              icon: const Icon(Icons.credit_card, size: 20),
              label: Text(
                  'Payer ma part · ${m.pricePerPlayerMad.toStringAsFixed(0)} MAD'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                foregroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Organisateur : saisir le score une fois le match commencé
          if (isCreator &&
              (m.status == 'CONFIRMED' || m.status == 'FULL') &&
              m.startsAt.isBefore(DateTime.now())) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _submitScore(m),
              icon: const Icon(Icons.emoji_events_outlined, size: 20),
              label: const Text('Saisir le score du match'),
            ),
            const SizedBox(height: 10),
          ],
          if (isAcceptedMember && iPaid && m.status != 'CONFIRMED') ...[
            _banner(
              Icons.check_circle,
              'Votre part est payée — en attente des autres joueurs.',
              AppColors.primary,
            ),
            const SizedBox(height: 10),
          ],
          primary,
        ],
      ),
    );
  }

  /// Carte de score du match joué (vainqueurs + score).
  Widget _scoreCard(PadelMatch m) {
    final winners = m.players
        .where((p) => m.winnerIds.contains(p.playerId))
        .map((p) => p.firstName)
        .join(' & ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winners.isEmpty ? 'Match joué' : 'Victoire de $winners',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (m.scoreText != null && m.scoreText!.isNotEmpty)
                  Text(
                    m.scoreText!,
                    style: const TextStyle(color: AppColors.slate),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton « Noter les joueurs » si tous ne sont pas encore notés.
  Widget _rateSection(PadelMatch m) {
    final myId = ref.read(authControllerProvider).user?.id;
    final rated = ref.watch(myRatingsProvider(m.id)).valueOrNull ?? const [];
    final remaining = m.players
        .where((p) =>
            p.status == 'ACCEPTED' &&
            p.playerId != myId &&
            !rated.contains(p.playerId))
        .length;
    if (remaining == 0) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          '⭐ Merci, vous avez noté tous vos partenaires.',
          style: TextStyle(color: AppColors.slate, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FilledButton.tonalIcon(
        onPressed: _busy ? null : () => _ratePlayers(m, rated),
        icon: const Icon(Icons.star_outline, size: 20),
        label: Text('Noter mes partenaires ($remaining)'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AppColors.amber.withValues(alpha: 0.14),
          foregroundColor: const Color(0xFF92600A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Ligne de demande en attente : accepter / refuser (organisateur).
  Widget _requestRow(PadelMatch m, MatchParticipant p) {
    final repo = ref.read(matchingRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.amber.withValues(alpha: 0.15),
            child: Text(
              p.initial,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.amber,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (p.level != null)
                  Text('Niveau ${_lvl(p.level!)}',
                      style: const TextStyle(
                          color: AppColors.slate, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refuser',
            onPressed: _busy
                ? null
                : () => _run(
                      () => repo.respond(m.id, p.playerId, accept: false),
                      'Demande refusée',
                    ),
            icon: const Icon(Icons.close, color: AppColors.danger),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.danger.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Accepter',
            onPressed: _busy
                ? null
                : () => _run(
                      () => repo.respond(m.id, p.playerId, accept: true),
                      '${p.firstName} a rejoint le match 🎾',
                    ),
            icon: const Icon(Icons.check, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _playerRow(MatchParticipant p, {String? isCreatorId}) {
    final isCreator = p.playerId == isCreatorId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              p.initial,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (p.level != null)
                  Text(
                    'Niveau ${_lvl(p.level!)}',
                    style: const TextStyle(
                        color: AppColors.slate, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (p.hasPaid)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: InfoChip(
                label: 'Payé',
                icon: Icons.check_circle,
                color: AppColors.primary,
              ),
            ),
          if (isCreator)
            const InfoChip(
              label: 'Organisateur',
              icon: Icons.star,
              color: AppColors.amber,
            ),
        ],
      ),
    );
  }

  Widget _emptySlot() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              child: const Icon(Icons.person_add_alt_1,
                  size: 20, color: AppColors.slate),
            ),
            const SizedBox(width: 12),
            const Text(
              'Place disponible',
              style: TextStyle(color: AppColors.slate),
            ),
          ],
        ),
      );

  Widget _glass(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _banner(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  static String _lvl(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Dialogue de saisie du score : sélection des 2 vainqueurs + score texte.
class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({required this.players});
  final List<MatchParticipant> players;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  final Set<String> _winners = {};
  final _score = TextEditingController();

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Score du match'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Qui a gagné ? (2 joueurs)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.players.map((p) {
              final sel = _winners.contains(p.playerId);
              return FilterChip(
                label: Text(p.firstName),
                selected: sel,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (v) => setState(() {
                  if (v && _winners.length < 2) {
                    _winners.add(p.playerId);
                  } else {
                    _winners.remove(p.playerId);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _score,
            decoration: const InputDecoration(
              labelText: 'Score (optionnel)',
              hintText: '6-4, 3-6, 7-5',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _winners.length == 2
              ? () => Navigator.pop(context,
                  (winners: _winners.toList(), score: _score.text.trim()))
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Feuille de notation : 3 critères étoilés par partenaire.
class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.players});
  final List<MatchParticipant> players;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  // playerId → [ponctualité, fair-play, justesse du niveau]
  late final Map<String, List<int>> _notes = {
    for (final p in widget.players) p.playerId: [5, 5, 5],
  };

  static const _criteria = ['Ponctualité', 'Fair-play', 'Niveau annoncé'];

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 20),
            const Text(
              'Notez vos partenaires',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...widget.players.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (int c = 0; c < 3; c++)
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              _criteria[c],
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.slate),
                            ),
                          ),
                          for (int s = 1; s <= 5; s++)
                            GestureDetector(
                              onTap: () => setState(
                                  () => _notes[p.playerId]![c] = s),
                              child: Icon(
                                s <= _notes[p.playerId]![c]
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.amber,
                                size: 26,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                widget.players
                    .map((p) => {
                          'playerId': p.playerId,
                          'punctuality': _notes[p.playerId]![0],
                          'fairplay': _notes[p.playerId]![1],
                          'levelAccuracy': _notes[p.playerId]![2],
                        })
                    .toList(),
              ),
              child: const Text('Envoyer mes notes'),
            ),
          ],
        ),
      ),
    );
  }
}
