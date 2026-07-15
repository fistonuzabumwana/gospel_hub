import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Styling constants
    final titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87,
    );

    final bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Amategeko y\'Ibwanga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gospel Hub Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Iyavuguruwe bwa nyuma: Nyakanga 2026',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gospel Hub twiyemeje kurinda ibyerekeye ibwanga by\'amakuru yawe. Iri tegeko ry\'ibwanga (Privacy Policy) risobanura uko twakira, dukoresha, kandi turinda amakuru yawe mugihe ukoresha porogaramu yacu (App).',
              style: bodyStyle,
            ),
            const Divider(height: 32),

            // Section 1
            Text('1. Amakuru twakira (Information We Collect)', style: titleStyle),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Konti ya Google (Google Account): Mugihe uhisemo gukoresha uburyo bwo kubika amakuru yawe kuri internet (Backup & Restore) ukinjira na Google Sign-In, twakira izina ryawe, imeyili (email), ndetse n\'ifoto yawe y\'umwirondoro (profile picture) kugira ngo tuguhe serivisi inoze kandi twerekane konti yawe.',
              bodyStyle,
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Amakuru y\'Imikoreshereze ya App (App Data): Kugira ngo dushobore kubika no kugarura amakuru yawe, tubika ibyo wasomye (reading history), amabara wasize ku mirongo (highlights), inyotes (notes) wanditse, ndetse na playlists z\'indirimbo wakoze.',
              bodyStyle,
            ),
            const Divider(height: 32),

            // Section 2
            Text('2. Uko dukoresha amakuru yawe (How We Use Your Info)', style: titleStyle),
            const SizedBox(height: 8),
            Text(
              'Dukoresha amakuru yakiriwe gusa kugira ngo tuguhe serivisi yo kubika no kugarura ibyo wakoze muri App (Cloud Backup & Restore).',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Amakuru yawe yose abikwa mu buryo bwizewe mu bubiko bwawe bwite bwa Google Drive bwagenewe iyi App (Hidden Application Data Folder). Gospel Hub NTIYEMEREWE kandi NTIYASHOBORA kusoma, guhindura cyangwa gusiba andi mafayili yose ari muri Google Drive yawe isanzwe.',
              style: bodyStyle,
            ),
            const Divider(height: 32),

            // Section 3
            Text('3. Gusangira amakuru n\'abandi (Data Sharing)', style: titleStyle),
            const SizedBox(height: 8),
            Text(
              'Ntabwo tugurisha, tugurisha cyangwa ngo dusangire amakuru yawe yite n\'abandi cyangwa izindi kompanyi. Dukoresha gusa serivisi zizewe za Google (Google Sign-In na Google Drive API) kugira ngo tubike amakuru yawe.',
              style: bodyStyle,
            ),
            const Divider(height: 32),

            // Section 4
            Text('4. Kurinda no kubika amakuru (Security & Retention)', style: titleStyle),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Kuri Terefone: Amakuru yose wasize kuri Bibiliya cyangwa playlists abikwa muri terefone yawe mu bubiko bwa SQLite.',
              bodyStyle,
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Kuri Internet (Cloud): Amakuru yoherezwa mu buryo buziguye avuye kuri terefone yawe ajya muri Google Drive yawe. Nta bubiko bwacu bwite bwihariye dufite bubika amakuru yawe.',
              bodyStyle,
            ),
            const Divider(height: 32),

            // Section 5
            Text('5. Uburenganzira bwawe (Your Rights)', style: titleStyle),
            const SizedBox(height: 8),
            Text(
              'Ushobora gusohoka (Sign Out) muri konti ya Google igihe cyose ubishakiye muri settings kugira ngo uhagarike isanisha ry\'amakuru. Ushobora kandi no gusiba burundu amakuru yose wari warabitse ukuyeho uruhushya rwa Gospel Hub mu maparametre ya konti yawe ya Google (Google Account Permissions).',
              style: bodyStyle,
            ),
            const Divider(height: 32),

            // Section 6
            Text('6. Twandikire (Contact Us)', style: titleStyle),
            const SizedBox(height: 8),
            Text(
              'Niba ufite ikibazo cyangwa igitekerezo bijyanye n\'iri tegeko ry\'ibwanga, ushobora kutwandikira kuri imeyili yacu:',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Email: support@gospelhub.app',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, TextStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6.0, right: 8.0, left: 4.0),
          child: CircleAvatar(radius: 3, backgroundColor: Colors.grey),
        ),
        Expanded(
          child: Text(text, style: style),
        ),
      ],
    );
  }
}
