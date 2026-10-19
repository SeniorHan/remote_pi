# desktop_drop (absorvido)

Cópia do [`desktop_drop` 0.5.0](https://pub.dev/packages/desktop_drop/versions/0.5.0)
(MixinNetwork/flutter-plugins, licença MIT em `LICENSE`), consumida por `path:`
no `cockpit/pubspec.yaml`. O nome do pacote foi mantido de propósito: o
registrant gerado pelo Flutter (podspec, CMake, `include/desktop_drop/`) não
muda, então macOS/Linux/Windows/mobile compilam exatamente como antes.

## Por que existe

Uma única mudança, em `macos/Classes/DesktopDropPlugin.swift` (`DropTarget`):
fora de um drag, `hitTest` devolve `nil`. Sem isso o `DropTarget` (que cobre a
`FlutterView` inteira) era a view sob o cursor para o AppKit, e o WebKit das
platform views (`WKWebView` das previews, `.panel`, navegador) descartava todo
`mouseMoved`: CSS `:hover` nunca acendia, cursor de link não mudava. Diagnóstico
em 2026-10-19 (memória `project_cockpit_webview_hover_desktop_drop`).

É o mesmo fix do upstream
([MixinNetwork/flutter-plugins#436](https://github.com/MixinNetwork/flutter-plugins/pull/436),
publicado no `desktop_drop` 0.9.0 em 2026-10-16).

## Quando remover

Quando o Flutter stable trouxer Dart >= 3.13.5 (o 3.50 beta traz 3.14), trocar
por `desktop_drop: ^0.9.1` no pubspec e apagar esta pasta. O 0.9.x também pede
`cross_file ^0.4`, que o `shadcn_flutter` só libera a partir do 0.0.54.
