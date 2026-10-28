import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';

const String kAppVersion = "1.0.0";

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pageRoute = ModalRoute.of(context)!.settings.arguments as String;

    if (pageRoute == "About") {
      return const _AboutScreen();
    }
    return _SidebarJsonPage(pageName: pageRoute);
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.about)),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 700
                ? constraints.maxWidth * 0.15
                : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(localizations),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: localizations.about,
                        body: localizations.aboutDescription,
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: localizations.aboutMissionTitle,
                        body: localizations.aboutMission,
                        icon: Icons.flag_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.verified_outlined,
                        label: localizations.aboutVersionLabel,
                        value: kAppVersion,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        icon: Icons.code,
                        label: localizations.aboutDeveloperTitle,
                        value: localizations.aboutDeveloper,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations localizations) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Image.asset("assets/sora_mark.png", fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        Text(
          localizations.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          localizations.aboutTagline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.teal.shade700),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Text(
            "$label:",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarJsonPage extends StatefulWidget {
  final String pageName;

  const _SidebarJsonPage({required this.pageName});

  @override
  State<_SidebarJsonPage> createState() => _SidebarJsonPageState();
}

class _SidebarJsonPageState extends State<_SidebarJsonPage> {
  late Future<List<Map<String, dynamic>>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final str = await rootBundle.loadString("assets/json/sidebar_en.json");
    final decoded = jsonDecode(str) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(decoded[widget.pageName]);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final pageTitle = widget.pageName == "About"
        ? localizations.about
        : widget.pageName;

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      backgroundColor: Colors.white,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: snapshot.data!.map((el) {
              if (el["type"] == "title") {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      el["content"],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              final content = el["content"]!.trim();
              final quoteMatch =
                  RegExp(r'^"(.+)"\s*\n+', dotAll: true).firstMatch(content);

              if (quoteMatch != null) {
                return _TestimonyCard(
                  quote: quoteMatch.group(1)!.trim(),
                  author: content.substring(quoteMatch.end).trim().replaceAll(RegExp(r'^~\s*'), ''),
                );
              }
              return Text(content, style: const TextStyle(fontSize: 20));
            }).toList(),
          );
        },
      ),
    );
  }
}

class _TestimonyCard extends StatelessWidget {
  final String quote;
  final String author;

  const _TestimonyCard({required this.quote, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote, color: Colors.teal),
              Expanded(
                child: Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "~ $author",
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
