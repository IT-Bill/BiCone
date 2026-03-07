import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  Uint8List? _imageData;
  String? _imageName;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showAlert('请填写反馈内容');
      return;
    }

    setState(() => _submitting = true);

    try {
      final feedback = SentryFeedback(
        message: message,
        contactEmail: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
      );
      final imageBytes = _imageData;
      final imageName = _imageName;
      final sentryId = await Sentry.captureFeedback(
        feedback,
        withScope: imageBytes != null
            ? (scope) {
                scope.addAttachment(
                  SentryAttachment.fromUint8List(
                    imageBytes,
                    imageName ?? 'screenshot.png',
                    contentType: 'image/png',
                  ),
                );
              }
            : null,
      );

      if (!mounted) return;
      if (sentryId == SentryId.empty()) {
        _showAlert('提交失败，反馈未发送');
      } else {
        _showAlert('感谢您的反馈！', onDismiss: () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showAlert('提交失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAlert(String message, {VoidCallback? onDismiss}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              onDismiss?.call();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _imageData = result.files.single.bytes;
        _imageName = result.files.single.name;
      });
    } else if (result != null && result.files.single.path != null) {
      final bytes = await File(result.files.single.path!).readAsBytes();
      setState(() {
        _imageData = bytes;
        _imageName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('意见反馈'),
        trailing: _submitting
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _submit,
                child: const Text('提交'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('联系方式（选填）'),
              children: [
                CupertinoTextFormFieldRow(
                  controller: _nameController,
                  prefix: const Text('名称'),
                  placeholder: '您的名称',
                  textInputAction: TextInputAction.next,
                ),
                CupertinoTextFormFieldRow(
                  controller: _emailController,
                  prefix: const Text('邮箱'),
                  placeholder: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('反馈内容'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CupertinoTextField(
                    controller: _messageController,
                    placeholder: '请描述您遇到的问题或建议...',
                    maxLines: 8,
                    minLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const BoxDecoration(),
                  ),
                ),
              ],
            ),
            // ── Screenshot ──
            CupertinoListSection.insetGrouped(
              header: const Text('截图（选填）'),
              children: [
                if (_imageData != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _imageData!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.trash,
                        color: CupertinoColors.destructiveRed),
                    title: const Text('移除截图',
                        style: TextStyle(
                            color: CupertinoColors.destructiveRed)),
                    onTap: () => setState(() {
                      _imageData = null;
                      _imageName = null;
                    }),
                  ),
                ] else
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.photo,
                        color: CupertinoColors.activeBlue),
                    title: const Text('添加截图'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _pickImage,
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                '您的反馈将通过 Sentry 提交，帮助我们改进应用体验。',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
