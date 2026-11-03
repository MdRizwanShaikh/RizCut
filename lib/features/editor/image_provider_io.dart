import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider fileImage(String path) => FileImage(File(path));
