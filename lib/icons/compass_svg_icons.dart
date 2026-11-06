import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG icon catalog for Rusa.
/// Strictly adheres to UI Constraint #5: "do not use generic Icon widget, use svg icon as much as possible".
class CompassSvg extends StatelessWidget {
  final String svgString;
  final double size;
  final Color? color;

  const CompassSvg({
    super.key,
    required this.svgString,
    this.size = 14.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
      colorFilter:
          color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}

class CompassSvgIcons {
  // MongoDB Signature Leaf Logo
  static const String mongoLeaf = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 2C12 2 8 8 8 13.5C8 17.5 10 20 12 22C14 20 16 17.5 16 13.5C16 8 12 2 12 2Z" fill="#00ED64"/>
  <path d="M12 2C12 2 11.8 7 11.8 13.5C11.8 17.5 12 22 12 22C12 22 12.2 17.5 12.2 13.5C12.2 7 12 2 12 2Z" fill="#001E2B" opacity="0.3"/>
</svg>
''';

  // Rusa brand mark — a simple deer head (placeholder; swap for the final
  // logo). Stroke-based so it can be tinted with `CompassSvg(color: ...)`.
  static const String rusa = '''
  <svg width="100%" height="100%" viewBox="0 0 994 573" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" xmlns:affinity="https://www.affinity.studio/" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2;">
      <g transform="matrix(1,0,0,1,-6396.658452,-152.712418)">
          <g transform="matrix(0.860964,0,0,0.860964,3494.915208,-344.211854)">
              <path d="M3947.593,1206.464C3947.102,1203.817 3947.039,1201.06 3947.457,1198.288C3947.831,1195.794 3948.574,1193.423 3949.629,1191.234C3951.184,1188.002 3953.402,1185.199 3956.081,1182.968C3958.568,1180.896 3961.468,1179.302 3964.64,1178.328C3966.635,1177.714 3968.725,1177.348 3970.868,1177.259C4048.66,1172.779 4127.174,1127.488 4152.724,1053.441C4178.312,979.286 4144.298,895.074 4085.664,843.595C4076.308,835.381 4074.52,821.492 4081.489,811.175C4088.458,800.859 4102.011,797.334 4113.124,802.948C4184.411,838.959 4237.982,896.849 4262.928,959.512C4306.78,824.138 4262.651,681.677 4166.126,623.029C4155.329,616.469 4151.214,602.824 4156.586,591.389C4161.957,579.953 4175.085,574.407 4187.028,578.528C4288.308,613.476 4359.748,698.298 4386.034,799.772C4422.765,780.491 4463.458,772.151 4502.513,777.278C4514.411,778.841 4523.47,788.721 4523.995,800.711C4524.52,812.7 4516.359,823.334 4504.643,825.93C4466.293,834.427 4426.261,862.88 4396.762,904.322C4395.173,938.006 4388.775,972.237 4377.115,1006.028C4315.4,1184.882 4130.059,1282.501 3964.133,1225.435C3962.2,1224.797 3960.384,1223.932 3958.711,1222.876C3955.661,1220.953 3953.117,1218.413 3951.202,1215.475C3949.436,1212.771 3948.193,1209.715 3947.593,1206.464Z" style="fill:white;"/>
          </g>
          <g transform="matrix(-0.860964,0,0,0.860964,10291.677118,-344.211854)">
              <path d="M3947.593,1206.464C3947.102,1203.817 3947.039,1201.06 3947.457,1198.288C3947.831,1195.794 3948.574,1193.423 3949.629,1191.234C3951.184,1188.002 3953.402,1185.199 3956.081,1182.968C3958.568,1180.896 3961.468,1179.302 3964.64,1178.328C3966.635,1177.714 3968.725,1177.348 3970.868,1177.259C4048.66,1172.779 4127.174,1127.488 4152.724,1053.441C4178.312,979.286 4144.298,895.074 4085.664,843.595C4076.308,835.381 4074.52,821.492 4081.489,811.175C4088.458,800.859 4102.011,797.334 4113.124,802.948C4184.411,838.959 4237.982,896.849 4262.928,959.512C4306.78,824.138 4262.651,681.677 4166.126,623.029C4155.329,616.469 4151.214,602.824 4156.586,591.389C4161.957,579.953 4175.085,574.407 4187.028,578.528C4288.308,613.476 4359.748,698.298 4386.034,799.772C4422.765,780.491 4463.458,772.151 4502.513,777.278C4514.411,778.841 4523.47,788.721 4523.995,800.711C4524.52,812.7 4516.359,823.334 4504.643,825.93C4466.293,834.427 4426.261,862.88 4396.762,904.322C4395.173,938.006 4388.775,972.237 4377.115,1006.028C4315.4,1184.882 4130.059,1282.501 3964.133,1225.435C3962.2,1224.797 3960.384,1223.932 3958.711,1222.876C3955.661,1220.953 3953.117,1218.413 3951.202,1215.475C3949.436,1212.771 3948.193,1209.715 3947.593,1206.464Z" style="fill:white;"/>
          </g>
      </g>
  </svg>
''';

  // Terminal / mongosh icon
  static const String terminal =
      '''<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="4 17 10 11 4 5"></polyline>
  <line x1="12" y1="19" x2="20" y2="19"></line>
</svg>
''';

  // Search / Query icon
  static const String search = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <circle cx="11" cy="11" r="8"></circle>
  <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
</svg>
''';

  // SlidersHorizontal / Options icon
  static const String sliders = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <line x1="21" y1="4" x2="14" y2="4"></line>
  <line x1="10" y1="4" x2="3" y2="4"></line>
  <line x1="21" y1="12" x2="12" y2="12"></line>
  <line x1="8" y1="12" x2="3" y2="12"></line>
  <line x1="21" y1="20" x2="16" y2="20"></line>
  <line x1="12" y1="20" x2="3" y2="20"></line>
  <line x1="14" y1="2" x2="14" y2="6"></line>
  <line x1="8" y1="10" x2="8" y2="14"></line>
  <line x1="16" y1="18" x2="16" y2="22"></line>
</svg>
''';

  // RotateCcw / Reset icon
  static const String rotateCcw = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="1 4 1 10 7 10"></polyline>
  <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"></path>
</svg>
''';

  // Database icon
  static const String database = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="12" cy="5" rx="9" ry="3"></ellipse>
  <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"></path>
  <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"></path>
</svg>
''';

  // Table2 / Collection icon
  static const String table = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="3" width="18" height="18" rx="2"></rect>
  <path d="M3 9h18"></path>
  <path d="M3 15h18"></path>
  <path d="M9 3v18"></path>
  <path d="M15 3v18"></path>
</svg>
''';

  // Code2 / JSON / Language Export icon
  static const String code = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="16 18 22 12 16 6"></polyline>
  <polyline points="8 6 2 12 8 18"></polyline>
</svg>
''';

  // Tree / Layers icon
  static const String layers = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>
  <polyline points="2 17 12 22 22 17"></polyline>
  <polyline points="2 12 12 17 22 12"></polyline>
</svg>
''';

  // BarChart2 / Schema icon
  static const String barChart = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <line x1="18" y1="20" x2="18" y2="10"></line>
  <line x1="12" y1="20" x2="12" y2="4"></line>
  <line x1="6" y1="20" x2="6" y2="14"></line>
</svg>
''';

  // Key / Index icon
  static const String key = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <circle cx="7.5" cy="15.5" r="5.5"></circle>
  <path d="m21 2-9.6 9.6"></path>
  <path d="m15.5 7.5 3 3L22 7l-3-3"></path>
</svg>
''';

  // Shield / Validation icon
  static const String shieldCheck = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
  <polyline points="9 12 11 14 15 10"></polyline>
</svg>
''';

  // Activity / Explain Plan icon
  static const String activity = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
</svg>
''';

  // Plus icon
  static const String plus = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <line x1="12" y1="5" x2="12" y2="19"></line>
  <line x1="5" y1="12" x2="19" y2="12"></line>
</svg>
''';

  // Trash2 / Delete icon
  static const String trash = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="3 6 5 6 21 6"></polyline>
  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
  <line x1="10" y1="11" x2="10" y2="17"></line>
  <line x1="14" y1="11" x2="14" y2="17"></line>
</svg>
''';

  // Copy icon
  static const String copy = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
  <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
</svg>
''';

  // File / Document icon
  static const String file = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
  <polyline points="14 2 14 8 20 8"></polyline>
</svg>
''';

  // Upload icon
  static const String upload = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
  <polyline points="17 8 12 3 7 8"></polyline>
  <line x1="12" y1="3" x2="12" y2="15"></line>
</svg>
''';

  // Download icon (mirror of upload)
  static const String download = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
  <polyline points="7 10 12 15 17 10"></polyline>
  <line x1="12" y1="15" x2="12" y2="3"></line>
</svg>
''';

  // Check / Success icon
  static const String check = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="20 6 9 17 4 12"></polyline>
</svg>
''';

  // Edit / Pencil icon
  static const String pencil = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path>
</svg>
''';

  // Eye / View icon
  static const String eye = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
  <circle cx="12" cy="12" r="3"></circle>
</svg>
''';

  // Chevron Down
  static const String chevronDown = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="6 9 12 15 18 9"></polyline>
</svg>
''';

  // Chevron Left
  static const String chevronLeft = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="15 18 9 12 15 6"></polyline>
</svg>
''';

  // Chevron Right
  static const String chevronRight = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="9 18 15 12 9 6"></polyline>
</svg>
''';

  // Chevron Up
  static const String chevronUp = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polyline points="18 15 12 9 6 15"></polyline>
</svg>
''';

  // Close / X icon
  static const String close = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <line x1="18" y1="6" x2="6" y2="18"></line>
  <line x1="6" y1="6" x2="18" y2="18"></line>
</svg>
''';

  // Play / Execute icon
  static const String play = '''
<svg viewBox="0 0 24 24" fill="currentColor" stroke="none" xmlns="http://www.w3.org/2000/svg">
  <polygon points="5 3 19 12 5 21 5 3"></polygon>
</svg>
''';

  // Menu / Hamburger icon
  static const String menu = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <line x1="3" y1="12" x2="21" y2="12"></line>
  <line x1="3" y1="6" x2="21" y2="6"></line>
  <line x1="3" y1="18" x2="21" y2="18"></line>
</svg>
''';

  // Sun / Light theme icon
  static const String sun = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="5"></circle>
  <line x1="12" y1="1" x2="12" y2="3"></line>
  <line x1="12" y1="21" x2="12" y2="23"></line>
  <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
  <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
  <line x1="1" y1="12" x2="3" y2="12"></line>
  <line x1="21" y1="12" x2="23" y2="12"></line>
  <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
  <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
</svg>
''';

  // Moon / Dark theme icon
  static const String moon = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
</svg>
''';

  // Zap icon
  static const String zap = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
</svg>
''';

  // ArrowUpDown / Sort icon
  static const String arrowUpDown = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="m21 16-4 4-4-4"></path>
  <path d="M17 20V4"></path>
  <path d="m3 8 4-4 4 4"></path>
  <path d="M7 4v16"></path>
</svg>
''';

  // MoreVertical / overflow menu icon
  static const String moreVertical = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="1"></circle>
  <circle cx="12" cy="5" r="1"></circle>
  <circle cx="12" cy="19" r="1"></circle>
</svg>
''';

  // Cut / scissors icon (text context menu)
  static const String cut = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <circle cx="6" cy="6" r="3"></circle>
  <circle cx="6" cy="18" r="3"></circle>
  <line x1="20" y1="4" x2="8.12" y2="15.88"></line>
  <line x1="14.47" y1="14.48" x2="20" y2="20"></line>
  <line x1="8.12" y1="8.12" x2="12" y2="12"></line>
</svg>
''';

  // Paste / clipboard icon (text context menu)
  static const String paste = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
  <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
</svg>
''';

  // Select all / dashed box icon (text context menu)
  static const String selectAll = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="4 3" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
</svg>
''';
}
