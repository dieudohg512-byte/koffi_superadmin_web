import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/institutions/data/institutions_repository.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/institution_functional_email.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';

Future<void> showInstitutionEmailsDialog({
  required BuildContext context,
  required InstitutionsRepository repository,
  required String institutionId,
  required String institutionName,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return InstitutionEmailsDialog(
        repository: repository,
        institutionId: institutionId,
        institutionName: institutionName,
      );
    },
  );
}

class InstitutionEmailsDialog extends StatefulWidget {
  const InstitutionEmailsDialog({
    super.key,
    required this.repository,
    required this.institutionId,
    required this.institutionName,
  });

  final InstitutionsRepository repository;
  final String institutionId;
  final String institutionName;

  @override
  State<InstitutionEmailsDialog> createState() =>
      _InstitutionEmailsDialogState();
}

class _InstitutionEmailsDialogState extends State<InstitutionEmailsDialog> {
  late Future<_EmailsBundle> _future;
  final Set<String> _justCopied = {};
  final Map<String, Timer> _copyTimers = {};
  bool _provisioning = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    for (final timer in _copyTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<_EmailsBundle> _load() async {
    final emails =
        await widget.repository.listFunctionalEmails(widget.institutionId);
    final credentials =
        await widget.repository.listAgentCredentials(widget.institutionId);
    return _EmailsBundle(
      emails: _sortEmailsByDirection(emails),
      credentials: credentials,
    );
  }

  /// Ordre décret (DST avant DSID) — évite de masquer DST / SECU en bas de liste.
  static List<InstitutionFunctionalEmail> _sortEmailsByDirection(
    List<InstitutionFunctionalEmail> emails,
  ) {
    const rank = <String, int>{
      'CAB': 1,
      'SE': 2,
      'DAAF': 3,
      'DDLP': 4,
      'DST': 5,
      'DADE': 6,
      'DSID': 7,
      'DPM': 8,
      'SECU': 8,
    };
    int codeRank(InstitutionFunctionalEmail mail) {
      final code = (mail.directionCode ?? mail.localPart ?? '')
          .trim()
          .toUpperCase();
      if (rank.containsKey(code)) return rank[code]!;
      final fromLocal = mail.email.split('.').first.toUpperCase();
      if (rank.containsKey(fromLocal)) return rank[fromLocal]!;
      return 100;
    }

    final sorted = [...emails]
      ..sort((a, b) {
        final byRank = codeRank(a).compareTo(codeRank(b));
        if (byRank != 0) return byRank;
        return a.directionNom.compareTo(b.directionNom);
      });
    return sorted;
  }

  Future<void> _provision() async {
    setState(() => _provisioning = true);
    try {
      final outcome =
          await widget.repository.provisionAccounts(widget.institutionId);
      if (!mounted) return;
      // Toujours recharger : les MDP déjà en base restent visibles même si
      // l'appel Edge a échoué (ex. comptes déjà créés à l'activation).
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.message),
          backgroundColor: outcome.ok ? null : AppTheme.danger,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec du provisionnement Auth. ($error)'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _provisioning = false);
    }
  }

  Future<void> _copyText(String key, String text) async {
    if (text.isEmpty || text == '—') return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _copyTimers[key]?.cancel();
    setState(() => _justCopied.add(key));
    _copyTimers[key] = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _justCopied.remove(key));
      _copyTimers.remove(key);
    });
  }

  Future<void> _copyEmail(String email) async {
    await _copyText('email:$email', email);
  }

  Future<void> _copyPassword(String email, String password) async {
    await _copyText('pwd:$email', password);
  }

  Future<void> _copyList(_EmailsBundle bundle) async {
    final byEmail = {
      for (final c in bundle.credentials) c.email.toLowerCase(): c,
    };
    final text = [
      for (final mail in bundle.emails)
        '${mail.labelWithSigle}\t${mail.email}\t${byEmail[mail.email.toLowerCase()]?.password ?? ''}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liste copiée (e-mail + MDP)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final compact = width < 720;
    final maxTableHeight = (size.height * 0.5).clamp(180.0, 640.0);
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: 16,
      ),
      title: FutureBuilder<_EmailsBundle>(
        future: _future,
        builder: (context, snapshot) {
          final count = snapshot.data?.emails.length;
          final suffix = count == null ? '' : ' ($count)';
          return Text('Comptes — ${widget.institutionName}$suffix');
        },
      ),
      content: SizedBox(
        width: compact ? width - 48 : 720,
        child: FutureBuilder<_EmailsBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text(
                'Impossible de charger les comptes.',
                style: TextStyle(color: AppTheme.danger),
              );
            }
            final bundle = snapshot.data ??
                const _EmailsBundle(emails: [], credentials: []);
            if (bundle.emails.isEmpty) {
              return const Text(
                'Aucun e-mail professionnel pour cette institution.',
                style: TextStyle(color: AppTheme.muted),
              );
            }
            final byEmail = {
              for (final c in bundle.credentials) c.email.toLowerCase(): c,
            };
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxTableHeight),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final mail in bundle.emails)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mail.labelWithSigle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  _CopyLine(
                                    value: mail.email,
                                    copied: _justCopied
                                        .contains('email:${mail.email}'),
                                    tooltip: 'Copier l’e-mail',
                                    onCopy: () => _copyEmail(mail.email),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final password = byEmail[
                                              mail.email.toLowerCase()]
                                          ?.password;
                                      final hasPassword = password != null &&
                                          password.isNotEmpty;
                                      return _CopyLine(
                                        value: hasPassword ? password : '—',
                                        copied: _justCopied
                                            .contains('pwd:${mail.email}'),
                                        tooltip: 'Copier le mot de passe',
                                        onCopy: hasPassword
                                            ? () => _copyPassword(
                                                  mail.email,
                                                  password,
                                                )
                                            : null,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bundle.emails.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${bundle.emails.length} comptes — faites défiler pour tout voir.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                          ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxTableHeight),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Direction')),
                          DataColumn(label: Text('E-mail')),
                          DataColumn(label: Text('Mot de passe')),
                        ],
                        rows: [
                          for (final mail in bundle.emails)
                            DataRow(
                              cells: [
                                DataCell(Text(mail.labelWithSigle)),
                                DataCell(
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          mail.email,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      _CopyButton(
                                        copied: _justCopied
                                            .contains('email:${mail.email}'),
                                        tooltip: 'Copier l’e-mail',
                                        onCopy: () => _copyEmail(mail.email),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Builder(
                                    builder: (context) {
                                      final password = byEmail[
                                              mail.email.toLowerCase()]
                                          ?.password;
                                      final hasPassword = password != null &&
                                          password.isNotEmpty;
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: SelectableText(
                                              hasPassword ? password : '—',
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          if (hasPassword)
                                            _CopyButton(
                                              copied: _justCopied.contains(
                                                'pwd:${mail.email}',
                                              ),
                                              tooltip: 'Copier le mot de passe',
                                              onCopy: () => _copyPassword(
                                                mail.email,
                                                password,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _provisioning ? null : _provision,
          icon: _provisioning
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1, size: 16),
          label: Text(
            _provisioning ? 'Provisionnement…' : 'Créer / rafraîchir Auth',
          ),
        ),
        FutureBuilder<_EmailsBundle>(
          future: _future,
          builder: (context, snapshot) {
            final bundle = snapshot.data ??
                const _EmailsBundle(emails: [], credentials: []);
            return TextButton.icon(
              onPressed:
                  bundle.emails.isEmpty ? null : () => _copyList(bundle),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copier'),
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _EmailsBundle {
  const _EmailsBundle({
    required this.emails,
    required this.credentials,
  });

  final List<InstitutionFunctionalEmail> emails;
  final List<InstitutionAgentCredential> credentials;
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({
    required this.value,
    required this.copied,
    required this.tooltip,
    required this.onCopy,
  });

  final String value;
  final bool copied;
  final String tooltip;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        if (onCopy != null)
          _CopyButton(copied: copied, tooltip: tooltip, onCopy: onCopy!),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.copied,
    required this.onCopy,
    this.tooltip = 'Copier',
  });

  final bool copied;
  final VoidCallback onCopy;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: copied ? 'Copié' : tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: copied ? null : onCopy,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          copied ? Icons.check : Icons.content_copy_outlined,
          key: ValueKey(copied),
          size: 18,
          color: copied ? AppTheme.accent : AppTheme.muted,
        ),
      ),
    );
  }
}
