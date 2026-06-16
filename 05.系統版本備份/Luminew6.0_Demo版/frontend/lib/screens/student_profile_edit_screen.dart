// fileName: lib/screens/student_profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models.dart';
import '../api_service.dart';
import '../theme/app_theme.dart'; // 引入設計系統
import '../widgets/luminew_header.dart';

class StudentProfileEditScreen extends StatefulWidget {
  final AppUser user;
  const StudentProfileEditScreen({super.key, required this.user});

  @override
  State<StudentProfileEditScreen> createState() => _StudentProfileEditScreenState();
}

class _StudentProfileEditScreenState extends State<StudentProfileEditScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false;
  Uint8List? _avatarBytes;
  String? _avatarName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _avatarBytes = result.files.first.bytes;
        _avatarName = result.files.first.name;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    
    try {
      // 這裡如果以後有實作上傳頭像 API 可以加入
      await ApiService.updateUserProfile(widget.user.email, _nameController.text);
      
      if (mounted) {
        widget.user.name = _nameController.text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('個人檔案已成功更新！'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失敗: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gooseYellow,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacings.pagePadding, 120, AppSpacings.pagePadding, 40),
            child: Column(
              children: [
                // --- 頭像區塊 (實作更換功能) ---
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            shape: BoxShape.circle,
                            boxShadow: AppDesign.premiumShadow,
                            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2), width: 4),
                          ),
                          child: ClipOval(
                            child: _avatarBytes != null
                                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.account_circle,
                                    size: 100,
                                    color: AppColors.primaryPurple,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                            Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacings.gapM),
                Text(
                  '點擊更換頭像',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacings.gapXL * 1.5),

                // --- 表單區塊 ---
                _buildStyledField(
                  label: '使用者姓名',
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  hint: "請輸入您的真實姓名",
                ),
                const SizedBox(height: AppSpacings.gapL),
                _buildStyledField(
                  label: '電子郵件',
                  controller: TextEditingController(text: widget.user.email),
                  icon: Icons.email_outlined,
                  enabled: false,
                ),
                
                const SizedBox(height: 60),

                // --- 儲存按鈕 (質感優化) ---
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primaryPurple.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.radiusM),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            '儲存個人檔案',
                            style: AppTextStyles.buttonText,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // --- 標頭 ---
          const LuminewHeader(
            title: '編輯個人檔案',
            showBackButton: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            label,
            style: AppTextStyles.h3.copyWith(fontSize: 14, color: AppColors.deepIndigo.withOpacity(0.8)),
          ),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          style: AppTextStyles.bodyLarge.copyWith(
            color: enabled ? AppColors.deepIndigo : AppColors.textDisabled,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? AppColors.primaryPurple : AppColors.textDisabled),
            filled: true,
            fillColor: enabled ? AppColors.surfaceWhite : AppColors.surfaceWhite.withOpacity(0.5),
            hintText: hint,
            hintStyle: AppTextStyles.caption,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
              borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
