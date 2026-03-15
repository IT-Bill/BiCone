import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  const ImagePreviewPage({super.key, required this.imageUrl, required this.heroTag});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  final TransformationController _transformController = TransformationController();

  bool get _hasAssetImage => widget.imageUrl.startsWith('assets/');

  Widget _buildImage() {
    if (_hasAssetImage) {
      return Image.asset(
        widget.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          CupertinoIcons.photo,
          size: 64,
          color: CupertinoColors.systemGrey,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const CupertinoActivityIndicator(
        color: CupertinoColors.white,
      ),
      errorWidget: (context, url, error) => const Icon(
        CupertinoIcons.photo,
        size: 64,
        color: CupertinoColors.systemGrey,
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Only dismiss if not zoomed in
        if (_transformController.value.isIdentity()) {
          Navigator.pop(context);
        } else {
          // Reset zoom
          _transformController.value = Matrix4.identity();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: widget.heroTag,
              child: _buildImage(),
            ),
          ),
        ),
      ),
    );
  }
}

class BlurredImageRoute extends PageRoute<void> {
  final String imageUrl;
  final String heroTag;

  BlurredImageRoute({required this.imageUrl, required this.heroTag});

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Color get barrierColor => CupertinoColors.black.withValues(alpha: 0.001);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          color: CupertinoColors.black.withValues(alpha: animation.value),
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ImagePreviewPage(imageUrl: imageUrl, heroTag: heroTag);
  }
}
