# Linkzora

Monitor de conectividade Android em Flutter: serviço em primeiro plano, notificação fixa com Live Update, alertas de mudança de estado, monitoria por servidor com gráfico interativo e diagnóstico de causa provável.

A documentação completa de funcionalidades, cálculos e arquitetura está em [docs/linkzora.md](docs/linkzora.md).

## Preparação

O projeto inclui a estrutura Flutter e a integração Android. Requer Flutter 3.35.7 ou compatível, SDK Android e aparelho ou emulador com Android 8 (API 26) ou superior. Na pasta do projeto, execute:

```bash
flutter pub get
flutter run
```

Para rodar os testes, execute `flutter test` e, em `android/`, `./gradlew :app:testDebugUnitTest`. Para gerar um APK de depuração, execute `flutter build apk --debug`. O arquivo será criado em `build/app/outputs/flutter-apk/app-debug.apk`. O `applicationId` e o `namespace` são `com.wifiwarnme.app`.

## Servidores de teste

Em **Ajustes > Servidor próximo**, é possível escolher uma destas infraestruturas públicas e distribuídas globalmente:

- Cloudflare — `1.1.1.1`
- Google Public DNS — `8.8.8.8`
- Quad9 — `9.9.9.9`

Em **Local do teste**, também é possível escolher a distância desejada:

- Próximo — usa o roteamento anycast de Cloudflare, Google ou Quad9.
- São Paulo — endpoint regional S3 `sa-east-1`.
- Estados Unidos — endpoint regional S3 da Virgínia `us-east-1`.
- Europa — endpoint regional S3 da Irlanda `eu-west-1`.

As categorias representam a região onde o endpoint foi implantado. A rota real continua sendo decidida pela operadora e pode atravessar outros locais.

O monitor usa a rede ativa do Android para abrir conexões TCP na porta 443. Cada ciclo faz uma conexão de aquecimento, descartada do resultado, e começa com cinco amostras. Quando encontra uma falha, jitter relevante ou latência a partir de 80% do limite configurado, coleta mais cinco amostras para confirmar o resultado. A latência exibida é a mediana. O jitter é a média da diferença entre amostras consecutivas (estilo RFC 3550). A perda é o percentual de conexões que falharam ou só foram estabelecidas após retransmitir o SYN (atraso de cerca de 1 s acima da mediana). O teste não altera o DNS configurado no aparelho; os servidores anycast são acessados por IP, e apenas os destinos regionais exigem resolução de nome. A porta 443 foi escolhida porque os três serviços oferecem DNS sobre HTTPS nela, evitando os bloqueios frequentes de ICMP usados pelo `ping`.

## Monitoria

A tela inicial identifica o servidor em uso e mostra quanto falta para a próxima verificação. Ao abrir o aplicativo, a splash mantém o ícone e o indicador de progresso visíveis enquanto uma nova medição é concluída. Se o monitoramento estiver desligado, essa leitura é pontual e o serviço é encerrado em seguida.

No cartão de monitoramento, **Alertas de mudança** permite escolher entre não emitir alertas, emitir apenas o primeiro alerta de cada sessão ou avisar a cada mudança de estado. A notificação fixa do serviço continua visível enquanto o monitoramento estiver ativo, conforme exigido pelo Android. Ela usa um canal silencioso de importância padrão com visibilidade pública, para aparecer na tela de bloqueio, e no Android 16 é solicitada como Live Update, com a latência no chip da barra de status. A exibição na tela de bloqueio depende da configuração de notificações na tela de bloqueio do aparelho.

A aba **Monitoria** guarda 24 horas de medições e resume esse período com:

- percentual de medições estáveis e períodos de instabilidade;
- seletor do servidor analisado: resumo, gráfico, causa provável e períodos de falha refletem apenas esse servidor, e a aba passa a seguir o novo servidor quando ele é trocado em Ajustes;
- gráfico interativo (fl_chart) de 1 h, 6 h ou 24 h, com linha colorida pelo estado, faixa de jitter, marcadores de queda, faixa de estados, limite configurado e mínimo, mediana, p95 e jitter médio;
- melhor faixa horária observada, calculada a partir de latência, jitter e perda;
- causa provável geral e em cada período de falha, baseada nos sinais realmente disponíveis ao app.

O diagnóstico diferencia ausência de rede, portal cativo, falha de DNS, rede sem acesso à internet, destino sem resposta, sinal Wi-Fi fraco, perda de pacotes, jitter alto, latência de um destino regional e possível congestionamento. Ele é uma classificação por evidências locais, não uma confirmação da causa dentro da rede da operadora. No Wi-Fi, o app também usa nível do sinal, RSSI e velocidade do enlace quando a permissão de localização permite acesso a esses dados.

O teste de velocidade mostrado pela Pesquisa Google usa o NDT7 da M-Lab. Ele descobre um servidor próximo, transfere dados em uma conexão WebSocket com TLS e coleta métricas TCP durante testes de download e upload de até cerca de dez segundos. Esse método mede capacidade e pode consumir dezenas de megabytes. O Linkzora adota apenas as ideias adequadas ao monitoramento contínuo — aquecimento, várias observações e estatísticas resistentes a picos — para preservar dados e bateria.

Referências oficiais: [especificação NDT7 da M-Lab](https://github.com/m-lab/ndt-server/blob/main/spec/ndt7-protocol.md), [regiões AWS](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html), [endpoints regionais S3](https://docs.aws.amazon.com/general/latest/gr/s3.html), [Cloudflare 1.1.1.1](https://developers.cloudflare.com/1.1.1.1/ip-addresses/), [Google Public DNS](https://developers.google.com/speed/public-dns/docs/using) e [Quad9](https://quad9.net/service/service-addresses-and-features/).

## Limitações

- A conexão TCP mede acessibilidade, latência, jitter e perda até o servidor escolhido, **não** a velocidade de download ou upload.
- Mudanças de rede são percebidas no próximo ciclo; a detecção instantânea por `ConnectivityManager.NetworkCallback` ainda não foi implementada.
- No modo Doze profundo, o Android limita o alarme de reserva a cerca de um disparo a cada 9 minutos, então o intervalo efetivo pode ser maior com a tela desligada por muito tempo.
- Notificações requerem permissão no Android 13+. Live Updates exigem Android 16. O tipo `specialUse` do serviço precisa de justificativa na Play Store.
- Eventos são limitados a 50 registros. As medições ficam em `files/measurements.jsonl`, com retenção de 24 horas.
- Apenas Android. Nenhuma implementação iOS.
