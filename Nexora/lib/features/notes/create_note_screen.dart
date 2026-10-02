import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/note_service.dart';
import '../../services/device_storage_service.dart';

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  File? _imageFile;
  PlatformFile? _documentFile;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx'],
    );
    if (result.isNotEmpty) {
      setState(() => _documentFile = result.first);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthService>();
    final user = auth.currentUser!;

    String? imageUrl;
    String? documentUrl;
    String? documentStoragePath;
    String? documentName;
    String? documentType;

    if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      imageUrl = await DeviceStorageService.saveFile(
        bytes: Uint8List.fromList(bytes),
        folder: 'notes/images',
        fileName: '${DateTime.now().millisecondsSinceEpoch}_image.jpg',
      );
    }

    if (_documentFile != null) {
      final docBytes = await _documentFile!.readAsBytes();
      if (docBytes.isNotEmpty) {
        documentName = _documentFile!.name;
        documentType = _documentFile!.extension ?? 'document';
        documentStoragePath = 'notes_documents/${DateTime.now().millisecondsSinceEpoch}_${documentName!.replaceAll(' ', '_')}';
        documentUrl = await DeviceStorageService.saveFile(
          bytes: Uint8List.fromList(docBytes),
          folder: 'notes_documents',
          fileName: '${DateTime.now().millisecondsSinceEpoch}_${documentName!.replaceAll(' ', '_')}',
        );
      }
    }

    String? err;
    try {
      await NoteService.publish(
        author: UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.name,
          regNo: user.regNo,
          branch: '',
          year: '',
          phoneNo: '',
          role: 'student',
          adminColorHex: null,
          approvedBy: 'self',
          approverColorHex: null,
          academic: AcademicInfo(proctorName: '', nptel: '', extraCurricular: '', clubs: []),
          courses: const [],
          searchIndices: SearchIndices(faculties: const [], regNoLower: '', nameLower: ''),
        ),
        title: _titleCtrl.text.trim(),
        body: _contentCtrl.text.trim(),
        imageUrl: imageUrl,
        documentUrl: documentUrl,
        documentStoragePath: documentStoragePath,
        documentName: documentName,
        documentType: documentType,
      );
      err = null;
    } catch (e) {
      err = 'Publish failed: $e';
    }

    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note published successfully'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Note'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.errorRed, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 200,
                  validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Title required',
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _contentCtrl,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 140),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                  validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Content required',
                ),
                const SizedBox(height: 20),

                // Image picker
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSlate,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.image, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Attach Image',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: Icon(Icons.add_photo_alternate, size: 20, color: AppTheme.brandBlue),
                            label: Text('Select', style: TextStyle(color: AppTheme.brandBlue)),
                            onPressed: _pickImage,
                          ),
                        ],
                      ),
                      if (_imageFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _imageFile!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: AppTheme.darkSlate.withValues(alpha: 0.8),
                                  radius: 18,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: AppTheme.errorRed),
                                    onPressed: () => setState(() => _imageFile = null),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Document picker
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSlate,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Attach Document',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: Icon(Icons.upload_file, size: 20, color: AppTheme.brandBlue),
                            label: Text('Select', style: TextStyle(color: AppTheme.brandBlue)),
                            onPressed: _pickDocument,
                          ),
                        ],
                      ),
                      if (_documentFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSlate.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _documentFile!.extension == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.description,
                                  color: AppTheme.brandBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _documentFile!.name,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppTheme.errorRed),
                                  onPressed: () => setState(() => _documentFile = null),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Publish Note'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}