import 'package:codelessly_api/codelessly_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'action_chain.dart';

/// Uploads and deletes files in the project's cloud storage folder for
/// [CloudFilesAction]s.
abstract final class CloudFiles {
  static const String name = 'CloudFiles';

  static const Map<String, String> _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
  };

  /// The content type for a file [extension].
  static String contentTypeFor(String extension) =>
      _contentTypes[extension.toLowerCase()] ?? 'application/octet-stream';

  /// The storage folder of the project the [codelessly] instance runs, kept
  /// apart for published and preview data like the cloud database.
  static String rootFolder(Codelessly codelessly) {
    final CloudDatabase? database = codelessly.cloudDatabase;
    if (database == null) {
      throw StateError('Cloud storage is not ready yet.');
    }
    final String root = switch (database.publishSource) {
      PublishSource.publish => 'data',
      PublishSource.preview => 'preview_data',
      PublishSource.template => 'template_data',
    };
    return '$root/${database.identifier}';
  }

  /// Joins a relative [path] to the project's folder, dropping empty and
  /// `..` segments so a path can't leave it.
  static String resolve(Codelessly codelessly, String path) {
    final List<String> segments = path
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && segment != '..')
        .toList();
    return [rootFolder(codelessly), ...segments].join('/');
  }

  /// Joins [folder] to [root], dropping empty and `..` segments; a private
  /// file goes under the uploader's own folder, `users/{uid}`, which storage
  /// rules keep to them.
  static String folderFor({
    required String root,
    required String folder,
    required CloudFileAccess access,
    required String? uid,
  }) {
    final List<String> segments = folder
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && segment != '..')
        .toList();
    if (access == CloudFileAccess.public) return [root, ...segments].join('/');
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to upload private files.');
    }
    return [root, 'users', uid, ...segments].join('/');
  }

  /// Performs [action].
  static Future<bool> perform(
    BuildContext context,
    CloudFilesAction action, {
    required Future<void> Function(List<ActionModel> actions) runActions,
  }) async {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    final Codelessly codelessly = context.read<Codelessly>();
    final String path = PropertyValueDelegate.substituteVariables(
      action.path,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: scopedValues,
    );
    final FirebaseStorage storage = FirebaseStorage.instanceFor(
      app: codelessly.firebaseApp,
    );

    switch (action.operation) {
      case CloudFilesOperation.delete:
        if (path.trim().isEmpty) return true;
        final Reference ref = path.startsWith('http')
            ? storage.refFromURL(path)
            : storage.ref(
                path.startsWith(rootFolder(codelessly))
                    ? path
                    : folderFor(
                        root: rootFolder(codelessly),
                        folder: path,
                        access: action.access,
                        uid: codelessly.firebaseAuth.currentUser?.uid,
                      ),
              );
        if (!ref.fullPath.startsWith('${rootFolder(codelessly)}/')) {
          throw StateError('Files outside the project can\'t be deleted.');
        }
        try {
          await ref.delete();
        } on FirebaseException catch (error) {
          // Already gone is what the action wants.
          if (error.code != 'object-not-found') rethrow;
        }
        return true;
      case CloudFilesOperation.upload:
        return _upload(
          context,
          action,
          codelessly,
          storage,
          path,
          runActions: runActions,
        );
    }
  }

  static Future<bool> _upload(
    BuildContext context,
    CloudFilesAction action,
    Codelessly codelessly,
    FirebaseStorage storage,
    String folder, {
    required Future<void> Function(List<ActionModel> actions) runActions,
  }) async {
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: action.fileType == CloudFilesType.image
          ? FileType.image
          : FileType.any,
      allowMultiple: action.allowMultiple,
      withData: true,
    );
    final List<PlatformFile> files = [
      for (final PlatformFile file in picked?.files ?? const [])
        if (file.bytes != null && file.size <= action.maxSizeMB * 1024 * 1024)
          file,
    ];
    if (files.isEmpty) return true;

    void setProgress(bool uploading, int current) {
      final VariableData? variable = action.progressVariable;
      if (variable == null) return;
      final notifier = codelesslyContext.findVariableByName(variable.name);
      notifier?.set(
        notifier.value.copyWith(
          value: {
            'uploading': uploading,
            'current': current,
            'total': files.length,
          },
        ),
      );
    }

    final String resolvedFolder = folderFor(
      root: rootFolder(codelessly),
      folder: folder,
      access: action.access,
      uid: codelessly.firebaseAuth.currentUser?.uid,
    );
    try {
      for (int index = 0; index < files.length; index++) {
        final PlatformFile file = files[index];
        setProgress(true, index + 1);
        final String extension = (file.extension ?? 'bin').toLowerCase();
        final String id = generateId();
        final Reference ref = storage.ref('$resolvedFolder/$id.$extension');
        await ref.putData(
          file.bytes!,
          SettableMetadata(contentType: contentTypeFor(extension)),
        );
        final String url = await ref.getDownloadURL();
        DebugLogger.instance.printInfo(
          'Uploaded ${file.name} to ${ref.fullPath}',
          name: name,
        );

        if (action.actions.isEmpty) continue;
        await ActionChain.run(
          () => runActions(action.actions),
          result: {
            'url': url,
            'path': ref.fullPath,
            'id': id,
            'name': file.name,
            'extension': extension,
            'contentType': contentTypeFor(extension),
            'size': file.size,
            'index': index,
            'total': files.length,
          },
        );
      }
    } finally {
      setProgress(false, 0);
    }
    return true;
  }
}
