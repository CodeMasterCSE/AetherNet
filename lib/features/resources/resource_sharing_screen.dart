import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../mesh/mesh_router.dart';
import '../../sync/sync_engine.dart';
import '../../models/resource.dart';
import '../../storage/local_storage.dart';
import '../../widgets/glass_card.dart';

class ResourceSharingScreen extends ConsumerStatefulWidget {
  const ResourceSharingScreen({super.key});

  @override
  ConsumerState<ResourceSharingScreen> createState() => _ResourceSharingScreenState();
}

class _ResourceSharingScreenState extends ConsumerState<ResourceSharingScreen> {
  bool _isUploading = false;

  Future<void> _pickAndShareFile(SyncEngine sync, MeshRouter mesh) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);
        final file = File(result.files.single.path!);
        final size = await file.length();
        final name = result.files.single.name;

        // Broadcast the metadata and file
        final resource = SharedResource(
          id: '${LocalStorage.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          path: file.path,
          senderId: LocalStorage.deviceId,
          senderName: LocalStorage.userName,
          size: size,
          timestamp: DateTime.now(),
        );
        sync.shareResource(resource);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shared $name'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    final mesh = ref.watch(meshProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Resource Sharing', style: TextStyle(color: Colors.white)),
      ),
      body: sync.sharedResources.isEmpty
          ? const Center(
              child: Text('No resources shared yet.\nTap + to share a file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sync.sharedResources.length,
              itemBuilder: (context, index) {
                final res = sync.sharedResources[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.insert_drive_file, color: Colors.white),
                      ),
                      title: Text(res.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Shared by ${res.senderName} • ${(res.size / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
                        onPressed: () => _openFile(res.path),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: _isUploading ? null : () => _pickAndShareFile(sync, mesh),
        icon: _isUploading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(_isUploading ? 'Uploading...' : 'Share File'),
      ),
    );
  }
}
