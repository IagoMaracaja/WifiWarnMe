# WifiWarnMe

MVP Android em Flutter: botão Monitorar ON/OFF, serviço Android em primeiro plano, notificação persistente, alertas de mudança de estado, histórico local e intervalo configurável.

## Preparação

Este repositório contém os arquivos de aplicação e a integração Android, **não** o scaffold Flutter completo nem binários gerados. Execute em uma pasta de trabalho:

```bash
flutter create --platforms=android --org com.wifiwarnme .
flutter pub get
flutter run
```

**Atenção:** `flutter create` pode regenerar arquivos Android. Verifique e preserve `android/app/src/main/AndroidManifest.xml` e os arquivos Kotlin em `android/app/src/main/kotlin/com/wifiwarnme/app/`. Confira se o `applicationId` e `namespace` em `android/app/build.gradle.kts` são `com.wifiwarnme.app`. Para builds atuais, ajuste compileSdk/targetSdk conforme o Flutter instalado.

## Limitações do MVP

- O endpoint HTTP 204 testa acessibilidade e tempo de resposta, **não** velocidade de download nem qualidade real do sinal Wi-Fi.
- As verificações periódicas usam o intervalo escolhido; detecção instantânea por ConnectivityManager.NetworkCallback e confirmação por múltiplas amostras ainda não foram implementadas.
- Notificações requerem permissão no Android 13+. O comportamento do foreground service depende da versão Android, otimização de bateria e políticas da Play Store (tipo specialUse precisa de justificativa).
- Histórico em SharedPreferences é limitado a 50 registros. Sem persistência de duração de quedas.
- O serviço não deve ser considerado validado até testes em aparelho real; o código não foi compilado neste ambiente.
- MVP apenas Android. Nenhuma implementação iOS.
