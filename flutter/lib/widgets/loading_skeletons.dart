// lib/widgets/loading_skeletons.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const Color _skeletonBase = Color(0xFFE9E9E9);
const Color _skeletonHighlight = Color(0xFFF7F7F7);

/// Lightweight shimmer used while a network image is still downloading.
///
/// Unlike the page/card skeletons below, this stays visible only inside the
/// image area. Once the bytes arrive, Flutter replaces it with the real image.
class ImageLoadingShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ImageLoadingShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
      ),
    );
  }
}

class _SkeletonShimmer extends StatelessWidget {
  final Widget child;

  const _SkeletonShimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      child: child,
    );
  }
}

/// Loading placeholder matching the current HOT [ProductCard] proportions.
/// This widget is used only while data is loading and does not affect the
/// actual product card layout.
class ProductCardSkeleton extends StatelessWidget {
  final bool showCompanyLogo;

  const ProductCardSkeleton({
    super.key,
    this.showCompanyLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final compact = width < 300;
        final veryCompact = width < 250;

        final outerPadding = veryCompact ? 8.0 : compact ? 10.0 : 12.0;
        final imageRadius = compact ? 17.0 : 20.0;
        final cardRadius = compact ? 22.0 : 26.0;
        final logoSize = veryCompact ? 32.0 : compact ? 36.0 : 40.0;

        return _SkeletonShimmer(
          child: Container(
            margin: EdgeInsets.fromLTRB(
              compact ? 1 : 2,
              compact ? 5 : 8,
              compact ? 1 : 2,
              compact ? 7 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    outerPadding,
                    outerPadding,
                    outerPadding,
                    0,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(imageRadius),
                        child: const AspectRatio(
                          aspectRatio: 3 / 2,
                          child: ColoredBox(color: Colors.white),
                        ),
                      ),
                      if (showCompanyLogo)
                        Positioned(
                          left: compact ? 8 : 12,
                          bottom: compact ? 8 : 12,
                          child: _SkeletonBox(
                            width: logoSize + 5,
                            height: logoSize + 5,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Positioned(
                        top: compact ? 7 : 10,
                        right: compact ? 7 : 10,
                        child: _SkeletonBox(
                          width: compact ? 29 : 33,
                          height: compact ? 29 : 33,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    outerPadding,
                    compact ? 6 : 7,
                    outerPadding,
                    compact ? 7 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(
                        width: compact ? 118 : 150,
                        height: compact ? 13 : 15,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      SizedBox(height: compact ? 4 : 5),
                      _SkeletonBox(
                        width: compact ? 90 : 124,
                        height: compact ? 10 : 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Row(
                        children: [
                          _SkeletonBox(
                            width: compact ? 54 : 65,
                            height: compact ? 21 : 24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          SizedBox(width: compact ? 4 : 7),
                          _SkeletonBox(
                            width: compact ? 66 : 78,
                            height: compact ? 21 : 24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _SkeletonBox(
                                width: compact ? 50 : 66,
                                height: compact ? 13 : 16,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              const SizedBox(height: 4),
                              _SkeletonBox(
                                width: compact ? 38 : 50,
                                height: compact ? 8 : 10,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    outerPadding,
                    compact ? 7 : 8,
                    outerPadding,
                    compact ? 8 : 9,
                  ),
                  child: Row(
                    children: [
                      _SkeletonBox(
                        width: compact ? 94 : 125,
                        height: compact ? 9 : 11,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const Spacer(),
                      _SkeletonBox(
                        width: compact ? 45 : 58,
                        height: compact ? 9 : 11,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Loading placeholder matching the current Deals [DealProductCard].
class DealProductCardSkeleton extends StatelessWidget {
  final double width;

  const DealProductCardSkeleton({
    super.key,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: const AspectRatio(
                      aspectRatio: 3 / 2,
                      child: ColoredBox(color: Colors.white),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _SkeletonBox(
                      width: 39,
                      height: 39,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  const _SkeletonBox(
                    width: 42,
                    height: 42,
                    shape: BoxShape.circle,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: 145,
                          height: 16,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 6),
                        _SkeletonBox(
                          width: 82,
                          height: 11,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SkeletonBox(
                    width: 48,
                    height: 22,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Row(
                children: [
                  _SkeletonBox(
                    width: 86,
                    height: 34,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SkeletonBox(
                        width: 42,
                        height: 9,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 4),
                      _SkeletonBox(
                        width: 64,
                        height: 17,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const _SkeletonBox(
                    width: 34,
                    height: 34,
                    shape: BoxShape.circle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HOME loading state mirrors the real horizontal product sections.
class HomeProductsSkeleton extends StatelessWidget {
  const HomeProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 72),
      itemCount: 3,
      itemBuilder: (context, sectionIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _SkeletonShimmer(
                  child: _SkeletonBox(
                    width: 155,
                    height: 20,
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width;
                  final cardWidth =
                  (availableWidth * 0.82).clamp(240.0, 325.0).toDouble();

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: const ProductCardSkeleton(),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: cardWidth,
                          child: const ProductCardSkeleton(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Deals loading state mirrors its search/tag header and horizontal sections.
class DealsProductsSkeleton extends StatelessWidget {
  const DealsProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _DealsHeaderSkeleton(),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 72),
              itemCount: 2,
              itemBuilder: (context, index) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                final cardWidth =
                (screenWidth * 0.74).clamp(260.0, 310.0).toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _SkeletonShimmer(
                          child: Row(
                            children: [
                              _SkeletonBox(
                                width: 132,
                                height: 22,
                                borderRadius:
                                BorderRadius.all(Radius.circular(7)),
                              ),
                              Spacer(),
                              _SkeletonBox(
                                width: 38,
                                height: 13,
                                borderRadius:
                                BorderRadius.all(Radius.circular(6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _SkeletonShimmer(
                          child: _SkeletonBox(
                            width: 72,
                            height: 11,
                            borderRadius:
                            BorderRadius.all(Radius.circular(5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DealProductCardSkeleton(width: cardWidth),
                            const SizedBox(width: 14),
                            DealProductCardSkeleton(width: cardWidth),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsHeaderSkeleton extends StatelessWidget {
  const _DealsHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        color: Colors.white,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SkeletonBox(
                    height: 48,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 10),
                _SkeletonBox(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(17),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 82,
              child: Row(
                children: List.generate(
                  5,
                      (index) => const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        children: [
                          _SkeletonBox(
                            width: 44,
                            height: 44,
                            shape: BoxShape.circle,
                          ),
                          SizedBox(height: 7),
                          _SkeletonBox(
                            width: 48,
                            height: 10,
                            borderRadius:
                            BorderRadius.all(Radius.circular(5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width list used by Favorites.
class ProductListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final bool showCompanyLogo;

  const ProductListSkeleton({
    super.key,
    this.count = 3,
    this.padding = const EdgeInsets.fromLTRB(0, 12, 0, 24),
    this.showCompanyLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      itemBuilder: (_, __) => ProductCardSkeleton(
        showCompanyLogo: showCompanyLogo,
      ),
    );
  }
}

/// Sliver form used by CompanyScreen for its initial products load.
class CompanyProductsSkeletonSliver extends StatelessWidget {
  final int count;

  const CompanyProductsSkeletonSliver({
    super.key,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (_, __) => const ProductCardSkeleton(showCompanyLogo: false),
        childCount: count,
      ),
    );
  }
}

/// Compact shimmer shown while the next catalogue page is loading.
/// It is intentionally small so already-rendered cards stay in place.
class PaginationLoadingSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const PaginationLoadingSkeleton({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _SkeletonBox(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(
                    width: 150,
                    height: 13,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  _SkeletonBox(
                    width: 96,
                    height: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SkeletonBox(
              width: 54,
              height: 16,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}

