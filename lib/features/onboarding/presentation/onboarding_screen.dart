import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../application/quiet_start_guide.dart';

class DovrenOnboardingScreen extends StatelessWidget {
  const DovrenOnboardingScreen({super.key});

  static const slides = <OnboardingSlide>[
    OnboardingSlide(
      title: 'QUIET THE\nRECIPE PAGE',
      description:
          'Start with a calmer reading space without the clutter around your ingredients.',
      image: 'assets/onboarding/quiet.png',
    ),
    OnboardingSlide(
      title: 'BLOCK THE\nDISTRACTIONS',
      description:
          'Dovren filters display ads, trackers, autoplay video, and pop-ups in Safari.',
      image: 'assets/onboarding/clean.png',
    ),
    OnboardingSlide(
      title: 'KEEP YOUR\nFOCUS',
      description:
          'Choose a focused mode for the kind of reading you want to do today.',
      image: 'assets/onboarding/focus.png',
    ),
    OnboardingSlide(
      title: 'READY WHEN\nYOU ARE',
      description:
          'Turn on Dovren in Safari Extensions and get back to the recipe.',
      image: 'assets/onboarding/ready.png',
    ),
  ];

  Future<void> finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dovren.onboarding.completed', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> continueGuide(BuildContext context) async {
    final guide = context.read<QuietStartGuide>();
    if (guide.isLastPage) {
      await finish(context);
      return;
    }
    await guide.advance();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => QuietStartGuide(pageCount: slides.length),
        child: Builder(
          builder: (context) {
            final guide = context.watch<QuietStartGuide>();
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ad dovren',
                            style: TextStyle(
                              color: DovrenTheme.ink,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            '${guide.currentPage + 1} / ${slides.length}',
                            style: const TextStyle(color: DovrenTheme.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: PageView.builder(
                          controller: guide.pages,
                          itemCount: slides.length,
                          onPageChanged: guide.recordVisiblePage,
                          itemBuilder: (_, index) =>
                              _SlideView(slide: slides[index]),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: index == guide.currentPage ? 30 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index == guide.currentPage
                                  ? DovrenTheme.orange
                                  : DovrenTheme.sage,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => continueGuide(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: DovrenTheme.ink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          guide.isLastPage ? 'OPEN AD DOVREN' : 'CONTINUE',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!guide.isLastPage)
                        Center(
                          child: TextButton(
                            onPressed: () => finish(context),
                            child: const Text(
                              'Skip intro',
                              style: TextStyle(color: DovrenTheme.muted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.image,
  });

  final String title;
  final String description;
  final String image;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(slide.image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            slide.title,
            style: const TextStyle(
              color: DovrenTheme.ink,
              fontSize: 36,
              height: .98,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            slide.description,
            style: const TextStyle(
              color: DovrenTheme.muted,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      );
}
