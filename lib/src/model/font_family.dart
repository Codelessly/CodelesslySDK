// Copyright (c) 2022, Codelessly.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE.md file.

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../../codelessly_sdk.dart';
import 'privacy_base.dart';

part 'font_family.g.dart';

/// Holds information about font family.
@JsonSerializable()
class FontFamilyModel extends PrivacyBase {
  /// Unique ID of the font family.
  final String id;

  /// Name of the font family.
  final String name;

  /// Different types of font variants this family contains.
  final List<FontVariantModel> fontVariants;

  /// Creates an instance of [FontFamilyModel] with given data.
  const FontFamilyModel({
    String? id,
    required this.name,
    required this.fontVariants,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  }) : id = id ?? name;

  FontFamilyModel.private({
    String? id,
    required this.name,
    required this.fontVariants,

    // Privacy
    required super.privacy,
  })  : id = id ?? name,
        super.private();

  /// Factory constructor for creating a new [FontFamilyModel] instance from
  /// JSON data.
  factory FontFamilyModel.fromJson(Map<String, dynamic> json) =>
      _$FontFamilyModelFromJson(json);

  /// Serializes this object into JSON data.
  @override
  Map<String, dynamic> toJson() => _$FontFamilyModelToJson(this);

  @override
  List<Object?> get props => [id, name, fontVariants];
}

/// Holds information about a font variant in a font family.
@JsonSerializable()
class FontVariantModel extends Equatable {
  /// Name of the variant. Ex. regular, thin, bold, etc.
  final String name;

  /// Font weight for this variant.
  final FontWeightNumeric weight;

  /// Font style for this variant.
  final String style;

  /// Source URL of this font from where it can be downloaded/accessed.
  final String fontURL;

  /// A URL for the preview image for this font.
  final String previewURL;

  /// Creates an instance of [FontVariantModel] with given data.
  const FontVariantModel({
    this.name = 'regular',
    this.weight = FontWeightNumeric.w400,
    this.style = 'Normal',
    this.fontURL = '',
    this.previewURL = '',
  });

  /// Factory constructor for creating a new [FontVariantModel] instance from
  /// JSON data.
  factory FontVariantModel.fromJson(Map<String, dynamic> json) =>
      _$FontVariantModelFromJson(json);

  /// Serializes this object into JSON data.
  Map<String, dynamic> toJson() => _$FontVariantModelToJson(this);

  @override
  List<Object?> get props => [weight, style];

  /// A factory constructor that creates an instance of [FontVariantModel] by
  /// parsing given [name].
  factory FontVariantModel.fromName(String name,
      {String fontURL = '', String previewURL = ''}) {
    FontWeightNumeric fileFontWeight = FontWeightNumeric.w400;
    String fileFontStyle = 'Normal';

    // Convert 'extra-bold' or 'extra bold' into 'extrabold'.
    final String modifiedName =
        name.toLowerCase().replaceAll('-', '').replaceAll(' ', '');

    // Check font weight.
    if (modifiedName.contains('thin')) {
      fileFontWeight = FontWeightNumeric.w100;
    } else if (modifiedName.contains('extralight')) {
      fileFontWeight = FontWeightNumeric.w200;
    } else if (modifiedName.contains('light')) {
      fileFontWeight = FontWeightNumeric.w300;
    } else if (modifiedName.contains('normal')) {
      fileFontWeight = FontWeightNumeric.w400;
    } else if (modifiedName.contains('regular')) {
      fileFontWeight = FontWeightNumeric.w400;
    } else if (modifiedName.contains('medium')) {
      fileFontWeight = FontWeightNumeric.w500;
    } else if (modifiedName.contains('semibold')) {
      fileFontWeight = FontWeightNumeric.w600;
    } else if (modifiedName.contains('extrabold')) {
      // Order matters, extrabold must come before bold.
      fileFontWeight = FontWeightNumeric.w800;
    } else if (modifiedName.contains('ultrabold')) {
      // Order matters, ultrabold must come before bold.
      fileFontWeight = FontWeightNumeric.w900;
    } else if (modifiedName.contains('bold')) {
      fileFontWeight = FontWeightNumeric.w700;
    } else if (modifiedName.contains('black')) {
      fileFontWeight = FontWeightNumeric.w900;
    } else if (modifiedName.contains('heavy')) {
      fileFontWeight = FontWeightNumeric.w900;
    } else if (modifiedName.contains('solid')) {
      // Exception for FontAwesome font.
      // TODO: Might need to remove this and use 'bold' for 'solid' style.
      fileFontWeight = FontWeightNumeric.w700;
    }

    // Check font style.
    if (modifiedName.contains('italic')) {
      fileFontStyle = 'Italic';
    }

    if (modifiedName.contains('oblique')) {
      fileFontStyle = 'Oblique';
    }

    return FontVariantModel(
      name: name,
      weight: fileFontWeight,
      style: fileFontStyle,
      fontURL: fontURL,
      previewURL: previewURL,
    );
  }
}
