import 'package:flutter/rendering.dart';

/// Status of an annotation
enum AnnotationStatus {
  pending,
  completed;

  String toJson() => name;

  static AnnotationStatus fromJson(String value) {
    return AnnotationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AnnotationStatus.pending,
    );
  }
}

/// A feedback message in the annotation thread
class AnnotationFeedback {
  final String id;
  final String author;
  final String text;
  final DateTime createdAt;

  AnnotationFeedback({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AnnotationFeedback.fromJson(Map<String, dynamic> json) {
    return AnnotationFeedback(
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Represents an annotation on a widget in the storyboard
class WidgetAnnotation {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Widget identification - stores enough info to re-locate the widget
  final String widgetType;
  final Rect? bounds;
  final String? widgetKey;

  /// Raw debugCreator string from the widget
  /// Example: "ReboundDropdown<String>(hint: "Select a state", value: null)"
  final String? widgetDebugInfo;

  /// Optional metadata
  final String? authorName;

  /// Status and completion tracking
  final AnnotationStatus status;
  final DateTime? completedAt;
  final String? completedBy;

  /// Feedback thread for multi-turn conversation
  final List<AnnotationFeedback> feedback;

  WidgetAnnotation({
    required this.id,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    required this.widgetType,
    this.bounds,
    this.widgetKey,
    this.widgetDebugInfo,
    this.authorName,
    this.status = AnnotationStatus.pending,
    this.completedAt,
    this.completedBy,
    this.feedback = const [],
  });

  WidgetAnnotation copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? widgetType,
    Rect? bounds,
    String? widgetKey,
    String? widgetDebugInfo,
    String? authorName,
    AnnotationStatus? status,
    DateTime? completedAt,
    String? completedBy,
    List<AnnotationFeedback>? feedback,
  }) {
    return WidgetAnnotation(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      widgetType: widgetType ?? this.widgetType,
      bounds: bounds ?? this.bounds,
      widgetKey: widgetKey ?? this.widgetKey,
      widgetDebugInfo: widgetDebugInfo ?? this.widgetDebugInfo,
      authorName: authorName ?? this.authorName,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      feedback: feedback ?? this.feedback,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'widgetType': widgetType,
    'bounds': bounds != null ? {
      'left': bounds!.left,
      'top': bounds!.top,
      'width': bounds!.width,
      'height': bounds!.height,
    } : null,
    'widgetKey': widgetKey,
    'widgetDebugInfo': widgetDebugInfo,
    'authorName': authorName,
    'status': status.toJson(),
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
    'feedback': feedback.map((f) => f.toJson()).toList(),
  };

  factory WidgetAnnotation.fromJson(Map<String, dynamic> json) {
    Rect? bounds;
    if (json['bounds'] != null) {
      final b = json['bounds'] as Map<String, dynamic>;
      bounds = Rect.fromLTWH(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['width'] as num).toDouble(),
        (b['height'] as num).toDouble(),
      );
    }

    return WidgetAnnotation(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      widgetType: json['widgetType'] as String,
      bounds: bounds,
      widgetKey: json['widgetKey'] as String?,
      widgetDebugInfo: json['widgetDebugInfo'] as String?,
      authorName: json['authorName'] as String?,
      status: json['status'] != null
          ? AnnotationStatus.fromJson(json['status'] as String)
          : AnnotationStatus.pending,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      completedBy: json['completedBy'] as String?,
      feedback: json['feedback'] != null
          ? (json['feedback'] as List<dynamic>)
              .map((f) => AnnotationFeedback.fromJson(f as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

/// Container for all annotations on a specific component/page
class ComponentAnnotations {
  final String componentRoute;
  final List<WidgetAnnotation> annotations;
  final DateTime? lastModified;

  ComponentAnnotations({
    required this.componentRoute,
    required this.annotations,
    this.lastModified,
  });

  int get count => annotations.length;

  ComponentAnnotations copyWith({
    String? componentRoute,
    List<WidgetAnnotation>? annotations,
    DateTime? lastModified,
  }) {
    return ComponentAnnotations(
      componentRoute: componentRoute ?? this.componentRoute,
      annotations: annotations ?? this.annotations,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
    'componentRoute': componentRoute,
    'annotations': annotations.map((a) => a.toJson()).toList(),
    'lastModified': lastModified?.toIso8601String(),
  };

  factory ComponentAnnotations.fromJson(Map<String, dynamic> json) {
    return ComponentAnnotations(
      componentRoute: json['componentRoute'] as String,
      annotations: (json['annotations'] as List<dynamic>)
          .map((a) => WidgetAnnotation.fromJson(a as Map<String, dynamic>))
          .toList(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
    );
  }
}
