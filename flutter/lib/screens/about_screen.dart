import 'package:flutter/material.dart';


class AboutScreen extends StatelessWidget {
  static const Color accentColor = Color(0xFFD1BC00);

  const AboutScreen({super.key});

  String _t(
      BuildContext context, {
        required String ru,
        required String en,
        required String hy,
      }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          _t(
            context,
            ru: 'О нас',
            en: 'About us',
            hy: 'Մեր մասին',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 104,
                          height: 104,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Appsosa',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t(
                            context,
                            ru: 'Удобные покупки. Выгодные предложения. Меньше потерь.',
                            en: 'Smarter shopping. Better deals. Less waste.',
                            hy: 'Հարմար գնումներ։ Շահավետ առաջարկներ։ Ավելի քիչ կորուստներ։',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AboutCard(
                    icon: Icons.auto_awesome_rounded,
                    title: _t(
                      context,
                      ru: 'Что такое Appsosa',
                      en: 'What is Appsosa',
                      hy: 'Ի՞նչ է Appsosa-ն',
                    ),
                    text: _t(
                      context,
                      ru: 'Appsosa — сервис, который помогает покупателям находить выгодные предложения на продукты и готовую еду, а магазинам, кафе и другим партнёрам — предлагать свои товары новым покупателям.',
                      en: 'Appsosa is a service that helps customers discover great deals on food and everyday products, while giving shops, cafés and other partners an easy way to offer their products to new customers.',
                      hy: 'Appsosa-ն ծառայություն է, որն օգնում է գնորդներին գտնել շահավետ առաջարկներ սննդամթերքի և այլ ապրանքների համար, իսկ խանութներին, սրճարաններին և այլ գործընկերներին՝ իրենց ապրանքներն առաջարկել նոր հաճախորդների։',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AboutCard(
                    icon: Icons.eco_outlined,
                    title: _t(
                      context,
                      ru: 'Наша цель',
                      en: 'Our goal',
                      hy: 'Մեր նպատակը',
                    ),
                    text: _t(
                      context,
                      ru: 'Мы хотим сделать покупки удобнее, помочь бизнесу эффективнее реализовывать товары и сократить количество продуктов, которые остаются невостребованными.',
                      en: 'Our goal is to make shopping more convenient, help businesses sell products more efficiently and reduce the amount of products that remain unused.',
                      hy: 'Մեր նպատակն է գնումները դարձնել ավելի հարմար, օգնել բիզնեսներին ավելի արդյունավետ իրացնել ապրանքները և նվազեցնել չիրացված ապրանքների քանակը։',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AboutCard(
                    icon: Icons.near_me_outlined,
                    title: _t(
                      context,
                      ru: 'Что можно делать в Appsosa',
                      en: 'What you can do in Appsosa',
                      hy: 'Ի՞նչ կարող եք անել Appsosa-ում',
                    ),
                    text: _t(
                      context,
                      ru: 'Находите предложения рядом, бронируйте товары, выбирайте доступный способ получения, сохраняйте любимые места и получайте уведомления о новых предложениях.',
                      en: 'Discover nearby offers, reserve products, choose an available collection option, save favorite places and receive notifications about new offers.',
                      hy: 'Գտեք մոտակա առաջարկները, ամրագրեք ապրանքներ, ընտրեք հասանելի ստացման տարբերակը, պահպանեք նախընտրելի վայրերը և ստացեք ծանուցումներ նոր առաջարկների մասին։',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AboutCard(
                    icon: Icons.handshake_outlined,
                    title: _t(
                      context,
                      ru: 'Для покупателей и партнёров',
                      en: 'For customers and partners',
                      hy: 'Գնորդների և գործընկերների համար',
                    ),
                    text: _t(
                      context,
                      ru: 'Мы постоянно развиваем Appsosa и стараемся делать сервис удобнее как для покупателей, так и для наших партнёров.',
                      en: 'We continuously improve Appsosa to make the experience better for both customers and our partners.',
                      hy: 'Մենք շարունակաբար զարգացնում ենք Appsosa-ն՝ այն ավելի հարմար դարձնելով ինչպես գնորդների, այնպես էլ մեր գործընկերների համար։',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Appsosa · Version 1.0.0\n© 2026 Appsosa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _AboutCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AboutScreen.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF766A00),
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
