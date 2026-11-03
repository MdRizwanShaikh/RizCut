import 'package:web/web.dart' as web;

const _svgId = 'rz-grade-svg';
const _filterId = 'rz-grade';
const _ns = 'http://www.w3.org/2000/svg';

void apply(String? svgMatrix) {
  final doc = web.document;
  if (svgMatrix != null) {
    var matrix = doc.getElementById('$_filterId-m');
    if (matrix == null) {
      final svg = doc.createElementNS(_ns, 'svg')
        ..id = _svgId
        ..setAttribute('width', '0')
        ..setAttribute('height', '0')
        ..setAttribute('style', 'position:absolute;width:0;height:0');
      final filter = doc.createElementNS(_ns, 'filter')
        ..id = _filterId
        ..setAttribute('color-interpolation-filters', 'sRGB');
      matrix = doc.createElementNS(_ns, 'feColorMatrix')
        ..id = '$_filterId-m'
        ..setAttribute('type', 'matrix');
      filter.appendChild(matrix);
      svg.appendChild(filter);
      doc.body?.appendChild(svg);
    }
    matrix.setAttribute('values', svgMatrix);
  }
  final videos = doc.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final v = videos.item(i) as web.HTMLElement;
    v.style.setProperty('filter', svgMatrix == null ? 'none' : 'url(#$_filterId)');
  }
}
