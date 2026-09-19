/* Flutter bootstrap override -- single purpose: serve CanvasKit from our own origin.
 *
 * Why: the default loader fetches canvaskit (~1.5MB wasm) from www.gstatic.com,
 * which is unreliable on some networks and shows up as a hung or blank page.
 * The --wasm build already ships the full canvaskit bundle under build/web/canvaskit/,
 * so the only thing we change is pointing flutter.js at it via config.canvasKitBaseUrl.
 *
 * Note: keep this as a block comment. The substituted {{flutter_js}} begins with an
 * inline IIFE, and a trailing line comment would swallow that line.
 * {{flutter_js}} and {{flutter_build_config}} are replaced by `flutter build`.
 */

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});