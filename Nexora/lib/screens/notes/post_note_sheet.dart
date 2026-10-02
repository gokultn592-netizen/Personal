import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:nexora/core/constants.dart';
import 'package:nexora/core/services/push_notification_service.dart';
import 'package:nexora/core/theme.dart';
import 'package:nexora/models/note_model.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/services/device_storage_service.dart';
import 'package:nexora/services/notification_service.dart';

class PostNoteSheet extends StatefulWidget {
  final UserModel currentUser;
  final NoteModel? noteToEdit;

  const PostNoteSheet({
    super.key,
    required this.currentUser,
    this.noteToEdit,
  });

  @override
  State<PostNoteSheet> createState() => _PostNoteSheetState();
}

class _PostNoteSheetState extends State<PostNoteSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  Uint8List? _imageBytes;
  String _imageName = 'note.jpg';
  String? _existingImageUrl;
  bool _imageRemoved = false;
  bool _isUploading = false;
  PlatformFile? _documentFile;

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      _titleController.text = widget.noteToEdit!.title ?? '';
      _contentController.text = widget.noteToEdit!.content;
      _existingImageUrl = widget.noteToEdit!.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      if (bytes.lengthInBytes > kMaxNoteImageBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'That image is ${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB. '
              'Maximum is ${(kMaxNoteImageBytes / (1024 * 1024)).round()} MB.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name.isEmpty ? 'note.jpg' : picked.name;
        _imageRemoved = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NexoraTheme.error,
            content: Text('Could not access image gallery: $e'),
          ),
        );
      }
    }
  }

  void _clearImage() => setState(() => _imageBytes = null);

  Future<void> _submitNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String? uploadedImageUrl;
      String? documentUrl;
      String? documentStoragePath;

      // Image upload (device only)
      if (_imageBytes != null) {
        uploadedImageUrl = await DeviceStorageService.saveFile(
          bytes: Uint8List.fromList(_imageBytes!),
          folder: 'notes/images',
          fileName: '${DateTime.now().millisecondsSinceEpoch}_$_imageName',
        );
      }

      // Document upload (device only)
      if (_documentFile != null) {
        final docBytes = await _documentFile!.readAsBytes();
        if (docBytes.isNotEmpty) {
          documentStoragePath = 'notes_documents/${DateTime.now().millisecondsSinceEpoch}_${_documentFile!.name.replaceAll(' ', '_')}';
          documentUrl = await DeviceStorageService.saveFile(
            bytes: Uint8List.fromList(docBytes),
            folder: 'notes_documents',
            fileName: documentStoragePath!.split('/').last,
          );
        }
      }

      if (_imageBytes != null && uploadedImageUrl == null) {
        throw Exception('Failed to save image.');
      }

      final noteTitle = _titleController.text.trim();
      final effectiveTitle = noteTitle.isEmpty ? 'Academic Note' : noteTitle;

      if (widget.noteToEdit != null) {
        // Updating existing note
        final updateData = <String, dynamic>{
          'title': noteTitle.isEmpty ? null : noteTitle,
          'content': _contentController.text.trim(),
          if (uploadedImageUrl != null)
            'imageUrl': uploadedImageUrl
          else if (_imageRemoved)
            'imageUrl': null,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.noteToEdit!.id)
            .update(updateData);

        // Broadcast notification to everyone
        await NotificationService().broadcastNoteNotification(
          noteId: widget.noteToEdit!.id,
          noteTitle: effectiveTitle,
          authorName: widget.currentUser.name,
          authorUid: widget.currentUser.uid,
          authorRegNo: widget.currentUser.regNo,
          isUpdate: true,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('Note updated and notification broadcasted to all students.'),
            ),
          );
        }
      } else {
        // Construct verified note model
        final note = NoteModel(
          id: '', // Generated by Firestore
          title: noteTitle.isEmpty ? null : noteTitle,
          content: _contentController.text.trim(),
          imageUrl: uploadedImageUrl,
          postedByUid: widget.currentUser.uid,
          authorName: widget.currentUser.name,
          authorRegNo: widget.currentUser.regNo,
          authorRole: widget.currentUser.role,
          authorAdminColorHex: widget.currentUser.adminColorHex ?? widget.currentUser.approverColorHex,
          authorPhotoUrl: widget.currentUser.photoUrl,
          timestamp: DateTime.now(),
        );

        // Commit note record to notes/ collection with author metadata
        final docRef = await FirebaseFirestore.instance.collection('notes').add(note.toMap());

        // Broadcast notification to everyone
        await NotificationService().broadcastNoteNotification(
          noteId: docRef.id,
          noteTitle: effectiveTitle,
          authorName: widget.currentUser.name,
          authorUid: widget.currentUser.uid,
          authorRegNo: widget.currentUser.regNo,
          isUpdate: false,
        );

        // Dispatch push notification to all members
        unawaited(PushNotificationService.instance.notifyAllNewNote(
          uploaderName: widget.currentUser.name,
          title: effectiveTitle,
          noteId: docRef.id,
        ));

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('Note committed to public feed with verified attribution.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NexoraTheme.error,
            content: Text('Submission failed: $e'),
          ),
        );
      }
    }
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

  Widget _buildDocumentPicker() {
    if (_documentFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: NexoraTheme.scaffold,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NexoraTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, color: NexoraTheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _documentFile!.name,
                style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: NexoraTheme.error, size: 18),
              onPressed: () => setState(() => _documentFile = null),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _isUploading ? null : _pickDocument,
      icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
      label: Text('Attach Document (PDF/DOCX/TXT)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: NexoraTheme.primary,
        side: const BorderSide(color: NexoraTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: NexoraTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: NexoraTheme.border, width: 1.5)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NexoraTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                widget.noteToEdit != null ? 'Update Academic Note' : 'Publish Academic Note',
                style: GoogleFonts.syne(
                  color: NexoraTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Non-Editable Identity Header Stamp
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: NexoraTheme.scaffold,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NexoraTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: NexoraTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield_outlined, color: NexoraTheme.primary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'Posting as: ',
                          style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(
                              text: widget.currentUser.name,
                              style: GoogleFonts.inter(
                                color: NexoraTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' · ',
                              style: GoogleFonts.inter(color: NexoraTheme.textSecondary),
                            ),
                            TextSpan(
                              text: widget.currentUser.regNo,
                              style: NexoraTheme.monoStyle(
                                color: NexoraTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Optional Title Input
              TextFormField(
                controller: _titleController,
                enabled: !_isUploading,
                style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Title (Optional)',
                  labelStyle: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),

              // Required Content Input
              TextFormField(
                controller: _contentController,
                enabled: !_isUploading,
                maxLines: 5,
                minLines: 3,
                style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14, height: 1.5),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Academic note content is required.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Note Content *',
                  labelStyle: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),

              // Image Attachment
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _clearImage,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_existingImageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _existingImageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 160,
                          color: NexoraTheme.scaffold,
                          child: const Center(
                            child: CircularProgressIndicator(color: NexoraTheme.primary, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 160,
                          color: NexoraTheme.scaffold,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined, color: NexoraTheme.textSecondary.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _isUploading
                            ? null
                            : () => setState(() {
                                  _existingImageUrl = null;
                                  _imageRemoved = true;
                                }),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text('Attach Reference Image', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexoraTheme.primary,
                    side: const BorderSide(color: NexoraTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              // Document Attachment
              _buildDocumentPicker(),
              const SizedBox(height: 14),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isUploading ? null : _submitNote,
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.noteToEdit != null ? 'Save & Broadcast Update' : 'Commit & Broadcast Note',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
