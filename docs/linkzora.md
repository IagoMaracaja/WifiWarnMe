# Linkzora — funcionalidades e contexto

Este documento descreve o que o Linkzora faz, como ele mede a conexão e como o código está organizado. Ele serve a quem vai usar, manter ou evoluir o app.

## Contexto

O Linkzora é um app Android, feito em Flutter, que vigia a qualidade da internet do aparelho em segundo plano. Ele responde a perguntas do dia a dia: "a internet caiu ou é o app que está lento?", "em que horário a conexão é melhor?", "o problema é meu Wi-Fi ou a rota até o servidor?".

Ele **não** é um teste de velocidade. Testes como o NDT7 da M-Lab, usado pela Pesquisa Google, transferem dezenas de megabytes para medir a capacidade. O Linkzora mede **disponibilidade, latência, jitter e perda** com poucas conexões TCP por verificação. Assim consegue rodar o dia inteiro sem gastar dados nem bateria de forma perceptível.

## Funcionalidades

### Configuração inicial

Na primeira abertura, antes da splash, um assistente de seis passos com indicador de progresso e botões Voltar/Continuar (o botão voltar do sistema também retrocede um passo):

1. **Boas-vindas**: ícone da marca, o que o app faz e o seletor de **idioma** (Sistema, Português, Español, English), para que o resto da configuração já apareça no idioma escolhido.
2. **Para onde medir**: local do teste e servidor próximo.
3. **Alertas de mudança**: sem alertas, uma vez por sessão ou a cada mudança.
4. **Ritmo das medições**: intervalo e limite de latência.
5. **Nome do Wi-Fi** (opcional): explica por que o Android exige a localização precisa. "Permitir" chama `requestWifiName`; "Pular" segue sem pedir.
6. **Tudo pronto**: resumo das escolhas, com o rótulo acima do valor para caber em qualquer idioma (um toque volta ao passo correspondente). **Começar monitoramento** chama `start`, que também pede a permissão de notificações; **Agora não** termina sem ligar o monitor.

Os padrões vêm pré-selecionados (Próximo · Cloudflare, a cada mudança, 2 min, 300 ms); em instalações anteriores, as escolhas já salvas são usadas. Ao terminar, tudo é salvo nas mesmas chaves que a tela Conexão lê, junto com a marca `onboardingDone`, e o app segue para a splash e a primeira leitura. Com a marca presente, o assistente não aparece mais.

### Navegação e aparência

- **Barra superior**: ícone, "Linkzora" e o subtítulo da aba (troca com animação). À direita, uma pílula de estado ao vivo: o ponto tem a cor do estado e pulsa a cada nova medição; o texto mostra o estado ("Estável", "Instável", "Sem resposta", "Medindo", "Pausado") na aba Conexão, que já exibe a latência no anel, e a latência nas demais abas. Depois vêm o botão de modo noturno (lua/sol) e o de Ajustes.
- **Abas** (Conexão, Monitoria, Eventos): barra flutuante de vidro com uma cápsula de destaque que desliza até a aba escolhida e um traço com o gradiente da marca acima do ícone. O conteúdo rola por baixo da barra, mas o fim de cada página sempre pode subir inteiro acima dela (veja "Páginas sob a barra de abas" em Padrão visual). Cada troca de aba entra com fade e um leve deslize na direção da aba.
- **Modo noturno**: ligado por padrão. Liga e desliga pelo botão da barra superior ou pelo item "Modo noturno" em Ajustes; vale na hora, com transição animada das cores, e fica salvo (chave `darkMode`). A splash, a configuração inicial e os ícones das barras de status e de navegação do sistema seguem a escolha.

### Tela Conexão

- **Anel de estado**: a cor indica o estado da última verificação: verde (estável), amarelo (instável), vermelho (sem resposta), azul (verificando) e cinza (pausado). Entre o anel e o mostrador há um canal uniforme com um leve tom da cor do estado; o mostrador usa o gradiente `dial` da paleta (no modo claro, um branco suave que acompanha as superfícies, nunca branco puro) com borda e brilho discretos na cor do estado. No centro aparecem o nome da rede, a latência, o jitter, a perda e quantas conexões foram bem-sucedidas.
- **Etiqueta do servidor** (canto superior esquerdo): mostra o ícone e o nome do destino em uso e abre os Ajustes.
- **Contagem regressiva** (abaixo do anel): mostra o tempo até a próxima verificação. Um toque força uma verificação imediata.
- **Cartão de monitoramento**: liga e desliga o serviço contínuo e escolhe o modo de alertas.
- **Identificar esta rede**: aparece quando o Android esconde o nome do Wi-Fi. Explica e pede a permissão de localização precisa, que o Android exige para revelar o SSID e o sinal.
- **Métricas**: intervalo, limite de latência e qualidade do sinal (RSSI em dBm no Wi-Fi).

### Tela Monitoria

Todos os cartões refletem **apenas o servidor selecionado** no menu suspenso "Servidor analisado". O menu mostra cada destino com o seu ícone, o número de medições nas últimas 24 h, a porcentagem de estabilidade e o selo **EM USO**. Os ícones (`_TargetMark`/`_TargetGlyph` em `ui_kit.dart`) são o logotipo da marca para os servidores anycast (Cloudflare, Google e Quad9, do pacote `simple_icons`, na cor da marca sobre um fundo levemente tingido) e a bandeira redonda para os destinos regionais (Brasil para São Paulo, EUA para Estados Unidos e União Europeia para Europa, do pacote `country_flags`); um destino desconhecido usa um globo. Os mesmos ícones aparecem na etiqueta do servidor da tela Conexão e nos seletores de destino de Ajustes e da configuração inicial (bandeiras nos cartões de local, logotipos monocromáticos nas pílulas de servidor). Quando o servidor muda em Ajustes, a tela passa a seguir o novo destino.

- **Resumo do servidor**: estabilidade (porcentagem de verificações estáveis), número de oscilações e melhor horário. O melhor horário é a hora do dia com a menor média de `latência + 2×jitter + 5×perda`, entre as horas com pelo menos duas amostras.
- **Pulso da latência**: gráfico interativo de 1 h, 6 h ou 24 h com:
  - linha colorida pelo estado de cada medição e faixa azul de jitter (latência ± jitter);
  - pontos vermelhos onde não houve resposta e linha tracejada do limite configurado;
  - faixa de estados abaixo do eixo; ao tocar, um balão mostra o horário, a latência e o jitter;
  - acima de 48 medições, os pontos são agrupados. Cada grupo mantém a latência média, o maior jitter e o pior estado, para que quedas curtas continuem visíveis;
  - rodapé com mínima, mediana, pico (p95) e jitter médio do período.
- **Causa provável**: diagnóstico da medição mais recente e as evidências usadas.
- **Períodos com falhas**: sequências de verificações não estáveis, com o horário, a duração, o pior estado e a causa provável.

### Tela Eventos

Linha do tempo das mudanças de estado dos últimos 30 dias (até 2000), agrupadas por dia, da mais recente para a mais antiga. Cada evento mostra o horário, a rede, o servidor e as métricas do momento.

- **Filtro por dia**: fileira de pílulas roláveis com "Todos" (padrão) e um dia por pílula ("Hoje", "Ontem" e "dd/MM" para os anteriores), cada uma com a contagem de eventos ("Hoje · 3").
- **Resumo**: cartão com o período escolhido ("Todos os dias" ou o dia), o total de mudanças e quantas foram **quedas** (internet indisponível), **instabilidades** e vezes em que a conexão **estabilizou**.
- O agrupamento e as contagens ficam em `lib/analytics.dart` (`groupEventsByDay`, `EventSummary`), calculados só quando chega um histórico novo. A linha nativa não tem ano: uma data posterior a amanhã é tratada como do ano anterior. A lista é montada sob demanda (`SliverList.builder`), então históricos longos não constroem todos os itens de uma vez.

### Tela Rede (dispositivos)

Mostra quem está na rede local, **onde está o problema** (rede da casa ou operadora) e a **contribuição provável** de cada causa, inclusive de cada aparelho, em percentuais que somam 100%. Nada é carregado antes da primeira visita à aba. O botão **Escanear agora** faz uma varredura completa (cerca de 15 s, com barra de progresso e a etapa atual), e a última varredura fica salva para a próxima abertura.

**O que o Android não permite.** Um app não enxerga o tráfego de outros aparelhos nem o consumo de banda de cada um: só o roteador tem esses contadores. Desde o Android 10 a tabela ARP (`/proc/net/arp`) é bloqueada, e desde o 11 o `ip neigh`, então **não há endereços MAC** (e os celulares usam MAC aleatório). Os aparelhos são identificados pelo IP e pelo que eles mesmos anunciam. A tela diz isso ao usuário e trata todo percentual como estimativa.

**Como os aparelhos são encontrados** (`NetworkScanner.kt`; as partes puras ficam em `DeviceDiscovery.kt`). Tudo roda em paralelo e preso à rede Wi-Fi, mesmo com VPN ativa:

| Fonte | O que traz |
|---|---|
| mDNS/DNS-SD (`NsdManager`) | Nome e tipo: `_googlecast`, `_airplay`, `_raop`, `_companion-link`, `_spotify-connect`, `_androidtvremote2`, `_amzn-wplay`, `_hap`, `_ipp`, `_printer`, `_smb`, `_workstation`, `_http`, `_device-info`, `_matter`, `_ssh`. Navega em lotes de 8 (o sistema limita cerca de 10 pedidos por app) e resolve um serviço por vez, como o Android exige antes da versão 14. O TXT dá o nome amigável (`fn`) e o modelo (`md`, `model`). |
| SSDP/UPnP | `M-SEARCH` para 239.255.255.250:1900 com `MulticastLock`. A descrição XML do `LOCATION` (lida só se servida pelo próprio IP que respondeu) traz `friendlyName`, fabricante, modelo e tipo (TV/MediaRenderer, roteador/InternetGatewayDevice). |
| DNS reverso (PTR) | Consulta UDP direto ao DNS do roteador: o DNS privado não conhece os nomes da rede local. |
| NetBIOS (UDP 137) | Nome de PCs Windows, NAS e Samba (consulta de status `*`). |
| Varredura | Todos os IPs da sub-rede (/24, ou até /22): ping ICMP (600 ms) e, sem resposta, TCP 80/443/62078/8009 (250 ms), 64 em paralelo. Uma conexão recusada também prova que o aparelho existe. |

As observações são unidas por IP. O nome segue a prioridade UPnP > mDNS > NetBIOS > DNS, sem o sufixo de domínio nem o MAC que alguns nomes `_workstation` trazem.

O **tipo** vem de regras sobre os serviços, o tipo UPnP e as palavras do nome e do modelo: roteador, TV/streaming, celular/tablet, computador, impressora, console, assistente/caixa de som, câmera, IoT ou desconhecido. O fabricante vem do UPnP ou de marcas conhecidas no nome.

Depois, cada aparelho recebe 5 sondagens (10 no roteador) por ICMP ou pela porta que respondeu, que mede a **latência local, o jitter e a perda**. Vale também a porta anunciada no mDNS, para PCs que bloqueiam ping. Ao mesmo tempo, 5 handshakes TCP até 1.1.1.1:443 dão a referência da internet no mesmo instante.

**Ambiente Wi-Fi** (`WifiEnvironment.kt`):

- **Scan de redes vizinhas**: precisa da localização precisa com o app aberto. O Android limita a 4 scans a cada 2 min, então o app pede um scan novo no máximo a cada 30 s. Se o sistema negar, usa os resultados em cache e avisa "dados em cache".
- **O que mostra**: faixa, canal, largura, RSSI e as redes vizinhas.
- **Sobreposição**: mesmo canal primário = "mesmo canal". Faixas de frequência que se cruzam = "sobreposta" (22 MHz no 2,4 GHz; a largura real no 5/6 GHz).
- **Pontuação de interferência**: soma da "altura" de cada rede sobreposta, `clamp((RSSI + 90) / 40, 0, 1)` (−90 dBm = 0, −50 dBm = 1). As parcialmente sobrepostas pesam 1,2, porque não coordenam o tempo de ar com a sua rede. Abaixo de 1 = baixa, até 3 = média, acima = alta.
- **Sugestão de canal**: no 2,4 GHz, sugere o canal 1, 6 ou 11 quando ele reduz a pontuação em pelo menos 0,8.

**Histórico para correlação.** Com o monitoramento ligado, depois de cada verificação o serviço mede o roteador (4 sondagens, cerca de 1 s, com wake lock próprio) e grava o resultado em `lan_probes.jsonl`. A cada 15 min, no Wi-Fi, faz um inventário leve em `devices.jsonl`: ping, mDNS e SSDP, sem latência por aparelho nem scan Wi-Fi novo, em cerca de 7 s. O escaneamento manual também entra no histórico.

**Regras dos percentuais** (`analyzeNetwork` em `lib/devices.dart`), sobre as verificações em Wi-Fi ou Ethernet das últimas 24 h:

1. **Evidência**: E é a soma de:
   - as verificações instáveis;
   - 2, se o roteador está ruim no último escaneamento (latência ≥ 50 ms, jitter ≥ 30 ms ou perda ≥ 25%);
   - 1, com interferência alta;
   - 1, com sinal fraco agora (≤ −75 dBm).

   Uma fração c = E / (E + 3) do total é explicada; o resto vai para **Sem causa identificada**. Sem nenhuma instabilidade, a tela mostra 100% sem causa e "Nenhum problema recente".
2. **Local × além do roteador**: L = (votos locais + 1) / (total de votos + 2).
   - Cada verificação instável com uma medição do roteador a até 3 min vota "local" (roteador ruim) ou "além do roteador" (roteador bom).
   - Falhas com sinal fraco e sem medição do roteador votam local.
   - O escaneamento atual soma 2 votos locais se o roteador está ruim, ou 1 externo se a última verificação falhou com o roteador bom.

   Com L ≥ 0,65 o veredito é **Rede local (Wi-Fi/casa)**; com L ≤ 0,35, **Operadora / internet**; entre os dois, "Dos dois lados". Sem nenhuma medição do roteador, "Ainda inconclusivo".
3. **Pesos**:
   - **Operadora / internet**: 2 × (1 − L). Inclui a rota até o servidor e a internet da casa saturada. Um aparelho que baixa muito não deixa o roteador lento no Wi-Fi, mas deixa a internet lenta; por isso os aparelhos também tiram parcela daqui, pela correlação.
   - **Sinal fraco do seu aparelho**: 2 × L × o maior entre a fração das falhas com sinal 0–1 e 0,8 × o sinal atual (1 se ≤ −75 dBm, 0,5 se ≤ −67 dBm).
   - **Interferência Wi-Fi**: 2 × L × min(pontuação / 3, 1).
   - **Cada aparelho** (fora o roteador e este celular; inclui os vistos no histórico de 24 h, marcados "ausente"): soma de quatro parcelas.
     - **Tipo**: 0,5 × o peso do tipo. TV e console 0,6; câmera 0,5; computador 0,4; celular 0,25; desconhecido 0,2; caixa de som 0,15; IoT 0,1; impressora 0,05. Vale a metade se o aparelho está ausente agora, e a soma dessas parcelas é limitada a 1.
     - **Diferença de instabilidade** × 4 (até 2): a taxa de verificações instáveis com o aparelho presente menos a taxa com ele ausente, ambas suavizadas como (u + 1) / (n + 2). Só conta com pelo menos 5 verificações de cada lado. O aparelho está presente numa verificação se o inventário mais próximo, a até 20 min, o encontrou.
     - **Entrada antes de falhas**: 0,5 por período de falha que começou até 30 min depois de o aparelho entrar na rede (até 1,5).
     - **Carga local** × L, de 0 a 1: 0,5 × clamp((latência − 30) / 150) + 0,3 × clamp((jitter − 10) / 50) + 0,2 se a perda ≥ 40%. Em celulares, × 0,4, porque em economia de energia eles respondem tarde mesmo parados.
   - **Folga local** fixa de 0,5, que vai para "Sem causa identificada".
4. Os pesos são normalizados para c e arredondados pelo maior resto, para somarem exatamente 100.

**Confiança** (baixa, média ou alta):

| Item | Regra |
|---|---|
| Operadora | Pelo número de falhas com medição do roteador: ≥ 10 alta, ≥ 3 média. |
| Sinal | Alta com ≥ 5 falhas e metade delas com sinal fraco. |
| Interferência | Média com o scan disponível; alta quando a interferência é alta e L ≥ 0,6. |
| Aparelho | Alta quando a comparação presente/ausente tem ≥ 10 verificações de cada lado; média com essa comparação ou com entrada antes de falha; baixa só com o tipo e a latência. |

Cada item lista os motivos em português, por exemplo "Instável em 40% das verificações com ele na rede, contra 8% sem ele", "Entrou na rede pouco antes de 2 períodos de falha" ou "Sempre presente: sem períodos sem ele para comparar".

**Tela**:

- **Cabeçalho "Onde está o problema"**: veredito, barra Rede local × Operadora, roteador × internet agora e o botão de escaneamento.
- **Contribuição provável**: rosca e barras com as causas (operadora, interferência, sinal, aparelhos somados e sem causa) e a confiança de cada uma.
- **Lista de aparelhos**: o roteador e este aparelho no topo, sem percentual. Os demais vêm ordenados pelo percentual, com ícone do tipo, nome, tipo/fabricante/modelo, IP e latência local. "Por quê?" abre os motivos e as fontes.
- **Cartão do ambiente Wi-Fi** e um aviso sobre os limites do Android.
- **Estados**: sem escaneamento, fora do Wi-Fi, falha, e localização negada ou desligada (com "Permitir", que reutiliza `requestWifiName`).

**Permissões**:

- `CHANGE_WIFI_MULTICAST_STATE`: SSDP.
- `CHANGE_WIFI_STATE`: `startScan`.
- `ACCESS_FINE_LOCATION`: já usada para o nome do Wi-Fi; também libera o scan de redes.

`NEARBY_WIFI_DEVICES` não é necessária: mDNS, SSDP e sockets não dependem dela, e o scan usa a localização em todas as versões.

**Validação real** (Samsung SM-G975F, Android 12, Wi-Fi de casa):

- 253 IPs varridos em cerca de 13 s, com 4 aparelhos encontrados:
  - o roteador (Broadcom "eRouter", via UPnP, mDNS e ping);
  - este aparelho;
  - um aparelho visto só por ping, em .20;
  - um PC "Spotify Desktop Launcher", via `_spotify-connect`, medido pela porta anunciada.
- Roteador 6 ms × internet 83 ms.
- Wi-Fi em 5 GHz, canal 132 / 80 MHz, −49 dBm, 30 redes vizinhas, nenhuma sobreposta.
- O inventário leve automático rodou em 6,8 s.

### Ajustes

- **Local do teste**: Próximo (anycast), São Paulo, Estados Unidos ou Europa.
- **Servidor próximo**: Cloudflare, Google ou Quad9, quando o local é "Próximo".
- **Modo noturno**: aplicado na hora, sem precisar salvar.
- **Idioma**: Sistema (padrão) ou um idioma fixo, com bandeiras; aplicado na hora, sem precisar salvar (veja "Idioma do app").
- **Intervalo**: 1, 2, 5, 10 ou 15 minutos.
- **Limite de latência**: de 30 a 2000 ms. Atalhos 30, 60, 80, 100, 200, 300, 400, 500, 750 e 1000 ms, ou **Personalizado**, que abre um campo numérico; valores fora da faixa ou vazios mostram o erro no próprio campo e bloqueiam "Salvar ajustes" (e "Continuar" na configuração inicial). Um valor salvo que não é atalho reabre como personalizado. Acima do limite, a conexão é considerada instável. O serviço nativo também limita o valor recebido a essa faixa (`ConnectionMath.clampMaxLatency`).

- **Pague um cafezinho**: cartão no fim de Ajustes (veja abaixo).

### Pague um cafezinho

Um cartão com uma xícara (ícone com vapor), a mensagem "Gostando do app? Que tal pagar um cafezinho pra esse dev ;)" e o botão **Pagar um cafezinho**, que abre https://buymeacoffee.com/andremaracaja no navegador (`url_launcher`, `LaunchMode.externalApplication`; o `AndroidManifest.xml` declara a consulta `VIEW` de `https` exigida pelo Android 11+). Se o link não abrir, um toast de erro mostra o endereço.

- **Onde**: sempre no fim de Ajustes (`_DonationCard` em `lib/donation.dart`).
- **Lembrete único**: depois de 7 dias de uso (a primeira abertura da tela Conexão fica em `firstUseAt`), o mesmo cartão aparece uma vez no fim da tela Conexão, com um botão de dispensar. Dispensar ou tocar no botão grava `donationNudgeDone` e ele não volta. Não há pop-up nem notificação.

### Notificações

- **Notificação fixa** (exigida pelo Android para o serviço em primeiro plano), desenhada em `design/notificacao/notificacao-redesign.png` (fonte em `notif.html`): o estado e a latência primeiro, o histórico como gráfico, os detalhes depois.
  - **Cabeçalho do sistema**: ícone na cor do estado, "Linkzora", o servidor e o horário da medição.
  - **Até o Android 15 (API < 36)**: cartão escuro próprio (`MonitorNotificationViews.kt` + `res/layout/notif_expanded.xml` e `notif_collapsed.xml`), igual com a aba de notificações clara ou escura e sem ícone grande à direita:
    - **expandida**: bloco com o ícone do transporte (Wi-Fi riscado quando sem resposta), nome da rede, "Wi-Fi 5 GHz · sinal bom" (ou "conectado sem internet") e a pílula do estado (**Estável**, **Instável**, **Sem resposta**); a **latência grande** com a unidade na cor do estado e "latência · limite 300 ms" (ou "0 de 5 conexões · limite 300 ms"); à direita, um **gráfico de barras das últimas 12 verificações** do servidor atual com a **linha tracejada do limite**, a barra mais recente com brilho e, para quem não respondeu, um toco vermelho sobre uma coluna apagada; a linha **Jitter · Perda · Sinal (dBm)**, com o jitter em amarelo quando instável e a perda na cor do problema; a **causa provável numa frase** com ícone ("Estável, sem problemas há 22 min.", "Rota congestionada ou servidor distante.", "Servidor ou rota sem resposta há 16 min."); e o rodapé "Medido às HH:mm" com a contagem regressiva "Próxima em mm:ss";
    - **recolhida** (~48 dp): ícone, nome da rede, "Estável · Wi-Fi 5 GHz", a tira das 12 verificações e a latência na cor do estado;
    - o gráfico e a tira são desenhados num bitmap (`ChartBitmaps`), porque `RemoteViews` não desenha; densidade limitada a 2× para manter a notificação leve;
    - textos, cores e a escala do gráfico vêm de `NotificationCard.kt` (`NotificationFormat`, `ChartScale`), sem tipos do Android.
  - **Android 16+ (API 36)**: modelo do sistema com **`ProgressStyle`**, para continuar promovida a **Live Update** (o Android não promove layouts próprios): título "Conexão estável · 81 ms", a causa e "Jitter · perda · Wi-Fi sinal", **12 segmentos**, um por verificação, e o anel do app como *tracker icon*; a latência vai para o **chip da barra de status** (`setShortCriticalText`). As cores pedidas para os segmentos são aplicadas pelo sistema quando a notificação é exibida promovida; na aba de notificações o Android 16 do emulador desenha a barra na cor de destaque do tema.
  - botões **Verificar agora** e **Pausar**;
  - usa um canal silencioso de importância padrão com visibilidade pública, para aparecer na tela de bloqueio.
- **Alertas de mudança** (canal de alta importância):
  - títulos por transição: "Internet indisponível", "Conexão instável", "Conexão voltou, mas instável" e "Conexão restabelecida", esta com a duração do problema;
  - o texto expandido traz a causa provável e as métricas;
  - um novo alerta substitui o anterior, em vez de acumular;
  - o botão **Ver monitoria** abre o app direto na aba Monitoria;
  - modos: sem alertas, uma vez por sessão de monitoramento, ou a cada mudança.

### Widgets

Dois widgets nativos de tela inicial (`AppWidgetProvider` + `RemoteViews`, em `MonitorWidgets.kt`), com o mesmo cartão escuro da notificação fixa (`#0E1A26`, igual com o tema claro ou escuro do launcher):

| Widget | Tamanho | Conteúdo |
|---|---|---|
| **Estado da conexão** (`LinkzoraSmallWidget`) | 2×1, redimensionável (mín. 110×40 dp) | Ícone do app, nome do Wi-Fi e, ao lado do ponto colorido, a latência (ou o estado, quando não há latência) seguida do estado. |
| **Monitor da conexão** (`LinkzoraLargeWidget`) | 4×2, redimensionável (mín. 200×110 dp) | Versão compacta: ícone do app, nome do Wi-Fi, estado e causa provável numa linha, botão de **verificar agora**, faixa contínua das últimas 12 verificações do servidor atual, Ping, Jitter e "Última medição HH:mm". A partir de ~250 dp de altura (4×3) mostra o cartão completo da notificação (caixa de Ping/Jitter, faixa, Perda e última medição) com o mesmo botão. |

- **Nome do Wi-Fi**: o Android só revela o SSID a um serviço iniciado com o app visível (tipo `location`). Quando o serviço volta sozinho (boot, atualização), o último nome é reutilizado apenas se a rede for a mesma (mesmo id de rede do Android), e o serviço renova o tipo `location` assim que o app é aberto.
- **Toque**: o cartão abre o app. O botão de atualizar envia `CHECK_NOW` ao serviço, que mede na hora.
- **Monitoramento desligado**: o estado fica cinza, "Pausado" / "Monitoramento pausado"; os últimos valores continuam visíveis como histórico e o botão de atualizar vira **Abrir app** (abrir o app retoma o monitoramento quando ele estava ligado). Uma medição avulsa (`probe`) também conta como pausado. Sem nenhuma medição ainda, aparece "Verificando…".
- **Atualização**: o `MonitorService` chama `MonitorWidgets.update` depois de publicar cada verificação, ao ligar (`start`/`configure`/`probe`) e ao desligar; o app chama ao trocar o idioma. O `updatePeriodMillis` de 30 min é só reserva (processo encerrado, monitoramento desligado). O trabalho roda numa thread própria, porque a faixa lê `measurements.jsonl`.
- **Android 12+**: cantos com `system_app_widget_background_radius` e `clipToOutline`, raiz `@android:id/background`, `targetCellWidth/Height`, `previewLayout` com valores de exemplo e `description`; o widget grande usa o mapa de tamanhos do `RemoteViews` para trocar entre compacto e completo. Antes do 12, a escolha usa a altura mínima informada nas opções do widget e a prévia é um desenho (`widget_preview_*_image.xml`).
- **Código**: os textos e as cores vêm do mesmo `MonitorCard` da notificação (`WidgetFormat` em `MonitorCard.kt`, sem tipos do Android). Os layouts reaproveitam os ids e os binders de `MonitorNotificationViews.kt`; a faixa fica em `res/layout/monitor_ribbon.xml`, incluída pela notificação e pelos widgets.
- **Limitações**: o botão de atualizar só funciona com o serviço em primeiro plano ativo (é a condição para o Android permitir iniciá-lo pelo launcher); a contagem regressiva não aparece no widget; o layout é fixo em 12 trechos de faixa, como na notificação.

### Idioma do app

A interface Flutter está em português, espanhol e inglês, com o `gen-l10n` oficial (`flutter_localizations` + `intl`).

- **Arquivos**: `l10n.yaml` aponta para `lib/l10n/`, com `app_pt.arb` (modelo), `app_es.arb` e `app_en.arb`. O `flutter gen-l10n` (também rodado pelo `flutter pub get`, por causa de `generate: true`) gera `lib/l10n/app_localizations*.dart`, que ficam versionados. Plurais e escolhas usam a sintaxe ICU (`{count, plural, =1{…} other{…}}`, `{level, select, …}`); os marcadores são declarados no modelo para manter a ordem dos parâmetros.
- **Uso**: os widgets leem os textos com `context.l10n` (`lib/language.dart`); fora do `Linkzora` (testes que montam só a `Home`) cai no português, como a paleta cai no modo escuro. A lógica pura (`analytics.dart`, `devices.dart`) recebe o `AppLocalizations` como parâmetro (`formatDuration`, `bestHourLabel`, `eventDayLabel`, `analyzeNetwork(l10n: …)`, `scanAgeLabel`, `NetworkDevice.displayName`…). Dia e mês curtos seguem o idioma ("16/10" em pt/es, "10/16" em en).
- **Escolha do idioma**: chave `language` com `system` (padrão), `pt`, `es` ou `en`. Com `system`, vale o primeiro idioma da lista do aparelho que tenha tradução; se nenhum tiver (francês, alemão…), **inglês** (`fallbackLanguage`), o mais compreendido dos três. A escolha é lida antes do primeiro quadro (como o modo noturno) e uma troca, no seletor ou no idioma do aparelho com "Sistema", vale na hora em todas as telas abertas.
- **Seletor**: `_LanguagePicker` com "Sistema" e um cartão por idioma com a bandeira (Brasil, Espanha e EUA, do `country_flags`) e o nome no próprio idioma; abaixo, o idioma que o "Sistema" usa agora. Aparece em Ajustes e na boas-vindas da configuração inicial.
- **Contrato com o nativo**: o idioma efetivo vai em `setLanguage` (`{'language': code}`) na abertura e a cada mudança, e como `language` nos argumentos de `start`, `configure` e `probe`. Um nativo antigo sem `setLanguage` é ignorado sem erro.
- **Textos que vêm do nativo**: o diagnóstico é traduzido pelo `diagnosisCode` (`localizeDiagnosis` em `analytics.dart`); sem código (medições antigas), pelo texto. Títulos e detalhes de eventos, nomes de transporte e diagnósticos antigos passam por `localizeNativeText`, que reconhece o texto em qualquer um dos três idiomas e devolve o do idioma atual; o resto (SSID, números) fica como está. O estado de um evento (queda, instável, estável) é lido do título em qualquer idioma. Os destinos são gravados com o nome canônico em português e exibidos com `targetDisplayName`; nomes em outro idioma ("United States", "Europe") são convertidos ao canônico por `canonicalTarget`, para não separar o histórico.

**Adicionar um texto**: crie a chave em `lib/l10n/app_pt.arb` (com `@chave` e `placeholders` quando houver parâmetros) e a mesma chave em `app_es.arb` e `app_en.arb`; rode `flutter gen-l10n` (ou `flutter pub get`) e use `context.l10n.chave` no widget.

**Adicionar um idioma**: crie `lib/l10n/app_<código>.arb` com todas as chaves, inclua o código em `supportedLanguages` e uma entrada em `_languageNames` (nome e bandeira) em `lib/language.dart`, e um `res/values-<código>/strings.xml` no Android para os textos nativos.

### Idioma dos textos nativos

Notificação fixa (cartão e modelo padrão, botões), alertas, nomes e descrições dos canais, eventos, diagnóstico, widgets e as etapas do escaneamento da aba Rede vêm de recursos Android: `res/values/strings.xml` (português, padrão), `res/values-es/strings.xml` e `res/values-en/strings.xml`.

- **Contrato com o Flutter**: o método `setLanguage` (`{'language': 'pt'|'es'|'en'}`) é chamado na abertura e sempre que o idioma efetivo muda, e responde com o idioma em uso. `start`, `configure` e `probe` também levam `language`. O idioma fica em `wifiwarnme_native`, chave `language`; sem ela, vale o idioma do sistema quando é pt/es/en, senão português.
- **Resolução**: `NativeLocale.localized` cria um contexto com o `Locale` escolhido (`createConfigurationContext`), para que valha o idioma do app e não só o do sistema. Como o launcher e a System UI inflam os `RemoteViews` com o idioma do sistema, todos os rótulos dos layouts também são definidos por código.
- **Troca de idioma**: com o serviço ativo, o app envia `REFRESH`; o serviço recria os canais (atualiza nome e descrição), redesenha a notificação com a última verificação e atualiza os widgets.
- **Diagnóstico**: `ConnectionMath.diagnosis` devolve um `DiagnosisCode`; o serviço o traduz. Cada medição nova guarda `diagnosis` (texto no idioma da época) e `diagnosisCode`. O snapshot envia `diagnosisCode`, `language` e `diagnosis` já no idioma atual; nas medições antigas, sem código, ele é deduzido do texto em português. Códigos: `no_network`, `captive_portal`, `dns_failure`, `no_internet`, `wifi_too_weak`, `no_response`, `weak_signal_stable`, `none`, `weak_signal`, `packet_loss`, `high_jitter`, `regional_distance`, `congested_route`.
- **Eventos**: continuam no formato "dd/MM HH:mm • título • detalhe • …"; os novos são gravados no idioma escolhido e os antigos não mudam.
- **Destinos**: o `targetName` gravado continua canônico ("São Paulo", "Estados Unidos", "Europa", "Cloudflare"…), porque a Monitoria agrupa por ele; só o texto exibido é traduzido.

## Como a medição funciona

Cada verificação roda no `MonitorService`, um serviço Android em primeiro plano:

1. Lê a rede ativa (`ConnectivityManager`): transporte (Wi-Fi, dados móveis, Ethernet), se a rede foi **validada** pelo Android e se há **portal cativo**. No Wi-Fi, com permissão, lê também o SSID, o RSSI, o nível de sinal (0–4) e a velocidade do enlace.
2. Resolve o endereço do destino. Para os servidores anycast é um IP fixo, sem DNS; para os destinos regionais (S3), é uma consulta DNS feita pela rede ativa.
3. Abre uma conexão TCP de **aquecimento** na porta 443, descartada, para absorver o custo de acordar o rádio, ARP e rota.
4. Abre **5 conexões TCP** (timeout de 2,5 s, intervalo de 120 ms) e mede o tempo do handshake.
5. Se a rodada for suspeita, coleta **mais 5**. São suspeitas as rodadas com falha, retransmissão, jitter instável ou mediana a partir de 80% do limite.

A porta 443 é usada porque os três provedores atendem DNS sobre HTTPS nela. Isso evita os bloqueios de ICMP que afetam o `ping`.

### Fórmulas (`ConnectionMath.kt`)

| Métrica | Cálculo |
|---|---|
| Latência | Mediana dos handshakes válidos, resistente a picos. |
| Retransmissão | Handshake ≥ mediana + 800 ms. O Linux reenvia um SYN sem resposta após 1 s, então esse atraso indica que o primeiro pacote se perdeu. |
| Jitter | Média da diferença absoluta entre amostras consecutivas (estilo RFC 3550, como em testes de velocidade), sem as retransmissões. |
| Perda | (conexões que falharam + retransmissões) ÷ tentativas. |
| Estado | **offline** sem nenhuma conexão; **instável** com latência acima do limite, qualquer perda ou jitter instável (≥ 30 ms e ≥ 1/3 da latência); **estável** nos demais casos. |

### Diagnóstico

Por ordem de prioridade:

- sem rede ativa;
- portal cativo (rede exige login);
- falha de DNS;
- rede conectada sem internet (não validada);
- Wi-Fi fraco demais;
- servidor ou rota sem resposta;
- sinal Wi-Fi fraco;
- perda de pacotes;
- oscilação alta;
- distância até o destino regional;
- rota congestionada.

Com a conexão estável e sinal fraco, o app informa "Sinal Wi-Fi fraco, mas conexão estável". O diagnóstico é uma **causa provável** baseada no que o aparelho consegue observar. Ele não enxerga a infraestrutura interna da operadora.

## Execução em segundo plano

- O agendamento usa um `Handler` e, como reserva, um alarme inexato `setAndAllowWhileIdle`. O `Handler` para quando a CPU dorme (modo Doze), e o alarme acorda o serviço. Quem disparar primeiro executa a verificação; o outro é ignorado.
- Durante a medição, um *wake lock* parcial de no máximo 60 s mantém a CPU acordada até o resultado ser publicado.
- No Doze profundo, o Android limita alarmes desse tipo a cerca de um a cada 9 minutos. Com a tela desligada por muito tempo, o intervalo efetivo pode ficar maior que o configurado. É o custo de não pedir alarmes exatos nem manter a CPU sempre ligada.

Se o monitoramento estava ligado, ele volta sozinho depois de reiniciar o aparelho ou atualizar o app (`BootReceiver`, `BOOT_COMPLETED` e `MY_PACKAGE_REPLACED`). Só Pausar e o interruptor do app desligam o monitoramento; uma parada decidida pelo sistema não o desliga.

## Armazenamento

| Dado | Onde | Retenção |
|---|---|---|
| Medições | `files/measurements.jsonl` (uma linha JSON por verificação) | 24 h, limpeza no máximo uma vez por hora |
| Eventos | `files/events.jsonl` (uma linha JSON `{timestamp, text}` por mudança de estado) | 30 dias e no máximo 2000 eventos, limpeza no máximo uma vez por hora |

O último estado registrado fica em `lastEventState` (prefs nativas), para que reinícios do serviço (cada abertura do app com o monitoramento desligado, atualizações) não registrem de novo o mesmo estado. A aba Eventos também ignora repetições consecutivas do mesmo estado já gravadas por versões anteriores, e trata o título antigo "Conexão lenta" como instável.
| Estado atual e configuração do serviço (incluindo `language` e `diagnosisCode`) | SharedPreferences `wifiwarnme_native` | — |
| Preferências da interface (incluindo `darkMode`) e marca da configuração inicial | SharedPreferences do Flutter | — |
| Inventários da aba Rede (`{timestamp, full, devices: [{ip, name, type}]}`) | `files/network/devices.jsonl` | 7 dias |
| Latência do roteador após cada verificação | `files/network/lan_probes.jsonl` | 7 dias |
| Último escaneamento completo | `files/network/last_scan.json` | Substituído a cada escaneamento |
| Hora do último inventário | SharedPreferences `linkzora_network` | — |

O histórico antigo, guardado como um array em SharedPreferences, é migrado automaticamente na primeira leitura. Os eventos antigos (texto em SharedPreferences, chave `events`, limitado aos 50 mais recentes e nunca zerado) também são migrados: como a linha só traz "dd/MM HH:mm", o ano é o atual, ou o anterior quando a data cairia no futuro ou depois do evento seguinte. Para o Flutter, `events` continua sendo a lista de linhas "dd/MM HH:mm • título • detalhe • …", da mais recente para a mais antiga, e o evento é gravado antes de `lastCheckedAt`, para já vir no histórico daquela verificação. Trinta dias cobrem o filtro por dia da aba Eventos com folga, e o teto de 2000 (cerca de 200 KB) limita o arquivo e o envio pelo canal mesmo numa rede que oscile o dia todo. A interface consulta o estado a cada segundo, mas o histórico só é enviado quando há uma medição nova (`knownCheckedAt`).

## Ícone e marca

A arte é um radar num quadrado arredondado azul-marinho (varredura verde, pontos amarelo e vermelho), com origem em 1024 px.

| Uso | Arquivo |
|---|---|
| Ícone adaptativo (API 26+, o mínimo do app) | `mipmap-anydpi-v26/ic_launcher.xml` e `ic_launcher_round.xml`: fundo `ic_launcher_background.png` (o gradiente azul-marinho estendido a 108 dp) e frente `ic_launcher_foreground.png` (o radar com borda esfumada; o anel externo tem ~56 dp, dentro da zona segura de 66 dp), em mdpi a xxxhdpi (108 a 432 px) |
| Ícone temático (Android 13+) | `drawable/ic_launcher_monochrome.xml`, o radar da notificação ampliado |
| Ícones legados | `mipmap-*/ic_launcher.png` (a arte inteira) e `ic_launcher_round.png` (recorte circular), de 48 a 192 px; o manifesto declara `android:icon` e `android:roundIcon` |
| Splash nativa | Android 12+: `windowSplashScreenAnimatedIcon` usa `@mipmap/ic_launcher` (o radar cabe no círculo); antes: `drawable-nodpi/linkzora_splash.png` (384 px, arte de 320 px) em `launch_background.xml` |
| Notificações | `drawable/ic_linkzora_notification.xml`: radar monocromático (anel externo, anel interno, mira, varredura e ponto) legível em 24 dp |
| Flutter (splash, barra superior, configuração inicial) | `assets/brand/linkzora_icon.png` (512 px) |

## Distribuição

Versões de teste vão pelo **Firebase App Distribution**, projeto `linkzora-app` (app `1:551246781244:android:0c1afa5ff117aec6ab1c39`), grupo de testadores `testers`.

- **Pipeline** (`.github/workflows/distribute.yml`): a cada push em `master` e sob demanda (com notas opcionais), roda os testes, gera o APK de release assinado, com número de build igual à contagem de commits, e publica para o grupo `testers` com a mensagem do commit como nota.
- **CI** (`.github/workflows/android.yml`): em PRs e pushes em `master`, roda `flutter analyze`, `flutter test`, os testes JVM e gera o APK de debug.
- **Assinatura**: `android/app/build.gradle.kts` lê `android/key.properties` e `android/app/linkzora-release.jks`, ambos fora do git. Sem eles, o release cai na chave de debug. No CI, eles são recriados a partir dos secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` e `ANDROID_KEY_ALIAS`. **A mesma chave precisa assinar todas as versões**, senão os testadores não conseguem atualizar; guarde uma cópia do `.jks` e da senha.
- **Credencial do Firebase**: o secret `FIREBASE_SERVICE_ACCOUNT` guarda a chave JSON de uma conta de serviço com o papel *Firebase App Distribution Admin*. Para criá-la: Console do Google Cloud → projeto `linkzora-app` → IAM e administrador → Contas de serviço → Criar → papel *Firebase App Distribution Admin* → Chaves → Adicionar chave → JSON; depois `gh secret set FIREBASE_SERVICE_ACCOUNT < chave.json`.
- **Publicação manual**: `flutter build apk --release` e `firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app <app id> --groups testers --project linkzora-app`.

## Arquitetura do código

| Arquivo | Papel |
|---|---|
| `lib/main.dart` | App, splash e telas (Conexão, Monitoria, Eventos, Ajustes), além dos seletores de destino, intervalo e limite compartilhados entre Ajustes e a configuração inicial. |
| `lib/onboarding.dart` | Configuração inicial exibida só na primeira abertura (marca `onboardingDone`). |
| `lib/analytics.dart` | Lógica pura: períodos de falha, disponibilidade, melhor horário, agrupamento do gráfico, estatísticas e eventos (leitura, agrupamento por dia e resumo). |
| `lib/monitoria_widgets.dart` | Gráfico, seletor de período, dropdown de servidor, modal e cartões de modo de alerta. |
| `lib/ui_kit.dart` | Componentes visuais compartilhados: painéis, ícones, cartões de escolha, seletores em pílula, botões, folhas, toasts, botões e pílula de estado da barra superior, barra de abas, padding das páginas sob a barra e ícones dos destinos. |
| `lib/palette.dart` | `LinkzoraPalette` (cores dos modos noturno e claro) e a preferência de modo noturno. |
| `lib/language.dart` | Idioma do app: resolução (sistema × escolha), `context.l10n`, envio ao nativo e o seletor com bandeiras. |
| `lib/l10n/` | Textos em `app_pt.arb` (modelo), `app_es.arb` e `app_en.arb`, e as classes geradas pelo `gen-l10n`. |
| `lib/donation.dart` | Cartão "Pague um cafezinho" e o lembrete único depois de 7 dias. |
| `MonitorService.kt` | Serviço em primeiro plano: agendamento, medição, notificações e alertas. |
| `ConnectionMath.kt` | Estatísticas e diagnóstico, sem dependências do Android. |
| `JsonLinesStore.kt` | Histórico em JSON lines com retenção por idade e teto de entradas (medições e eventos). |
| `EventLog.kt` | Eventos da aba Eventos sobre o `JsonLinesStore`, formato da linha e migração dos eventos antigos. |
| `MonitorCard.kt` | Textos, cores e faixa de estados do cartão dos widgets, sem dependências do Android. |
| `NotificationCard.kt` | Modelo da notificação fixa redesenhada: pílula, legenda, causa em frase, barras e escala do gráfico, sem dependências do Android. |
| `BootReceiver.kt` | Retoma o monitoramento depois de reiniciar o aparelho ou atualizar o app. |
| `MonitorNotificationViews.kt` | Layouts personalizados (RemoteViews) da notificação fixa abaixo do Android 16 e o desenho do gráfico (`ChartBitmaps`); os binders antigos servem aos widgets. |
| `MonitorWidgets.kt` | Widgets de tela inicial (`LinkzoraSmallWidget`, `LinkzoraLargeWidget`) e a atualização deles. |
| `NativeLocale.kt` | Idioma dos textos nativos (`setLanguage`, contexto localizado) e `NativeText`, que traduz diagnóstico, cartão e destinos. |
| `AppLanguage.kt` | Regras puras do idioma: códigos aceitos, padrão do sistema e `Locale`. |
| `MainActivity.kt` | Canal `wifiwarnme/monitor` entre Flutter e o serviço. |
| `NetworkScanner.kt` | Aba Rede: varredura (mDNS, SSDP/UPnP, PTR, NetBIOS, ping/TCP), latência por aparelho, roteador × internet, medição do roteador após cada verificação e inventário de 15 min. |
| `DeviceDiscovery.kt` | Partes puras da varredura: SSDP e descrição UPnP, NetBIOS, PTR, classificação do tipo, união por IP, estatísticas locais e cálculo de canais Wi-Fi. |
| `WifiEnvironment.kt` | Redes vizinhas, sobreposição de canais e interferência, respeitando o limite de scans. |
| `DeviceInventoryStore.kt` | Histórico de inventários e do roteador (7 dias) e o último escaneamento. |
| `lib/devices.dart` | Lógica pura da aba Rede: modelos do escaneamento e as regras de "onde está o problema" e dos percentuais. |
| `lib/devices_page.dart` | Tela da aba Rede (`_DevicesPage`). |

Métodos do canal: `status` (com `knownCheckedAt`), `start`, `configure`, `probe`, `checkNow`, `stop`, `requestWifiName`, `setLanguage` e, da aba Rede, `scanNetwork`, `scanProgress` e `deviceHistory`.

### Padrão visual

Nenhuma cor fica fixa nos widgets: todas vêm de `LinkzoraPalette` (`lib/palette.dart`), um `ThemeExtension` com as variantes `LinkzoraPalette.dark` e `LinkzoraPalette.light`. Os widgets leem a paleta com `context.palette` (fora do `Linkzora`, como em testes que montam só a `Home`, ela cai na variante escura). Como a paleta viaja no tema, o `lerp` dela anima todas as cores na troca de modo. A paleta também gera o `ThemeData` (`palette.theme`) e o estilo das barras do sistema (`palette.overlayStyle`).

| Papel | Noturno | Claro |
|---|---|---|
| Fundo (`bg`) | `#07121E` | `#EEF3F7` |
| Destaque / estável (`accent`) | `#20E3A2` | `#0B9A70` |
| Gradiente da marca (`brand`) | `#20E3A2` → `#28B8F0` | `#0FA67A` → `#1B8FD0` |
| Instável (`slow`) | `#FFC857` | `#B7740F` |
| Sem resposta (`offline`) | `#FF6B78` | `#D33445` |
| Informação / verificando (`info`) | `#70B7FF` | `#2A78D0` |

Além delas há textos (`text`, `textSoft`, `muted`), superfícies (`surface`, `surfaceBright`), gradientes de painel (`panel`, `panelRaised`), borda, sombra, brilho do ícone, balão do gráfico e as cores da splash. No modo claro as cores de estado são mais escuras para manter o contraste sobre fundo branco; `onAccent` é a cor de texto sobre o destaque.

Para adicionar uma cor: crie o campo em `LinkzoraPalette`, defina o valor em `dark` e em `light` e inclua-o no `lerp`. Nunca use `Color(0x…)` direto num widget.

#### Páginas sob a barra de abas

A barra de abas flutua sobre o conteúdo (`Scaffold.extendBody`). Com isso, o Scaffold soma a altura da barra (que já inclui a margem inferior da área segura) ao `MediaQuery.padding.bottom` do corpo. Toda página de aba deve usar `_tabPagePadding(context, …)` com um `context` de **dentro** do corpo (por isso cada página é montada num `Builder`), nunca o `context` do `State` acima do Scaffold, que não enxerga a barra. Assim o último item sempre rola inteiro acima da barra, inclusive nos estados vazios. A barra aceita quatro abas sem quebrar o layout (rótulos com reticências).

Telas novas devem montar a interface com os componentes de `ui_kit.dart` (`_Panel`, `_IconBadge`, `_ChoiceCard`, `_Segmented`, `_PillTrack`/`_PillOption`, `_SwitchRow`, `_GradientButton`, `_GlassSheet`, `_showToast`), em vez de componentes Material padrão.

## Testes

```bash
flutter test                                            # lógica e telas (Dart)
cd android && ./gradlew :app:testDebugUnitTest          # cálculos e armazenamento (Kotlin)
```

- `test/analytics_test.dart`: períodos de falha, disponibilidade, melhor horário, agrupamento do gráfico, estatísticas e eventos (data com ano inferido, rótulos Hoje/Ontem, agrupamento por dia, resumo e um histórico de 2000 eventos).
- `test/home_test.dart`: telas com o canal nativo simulado. Cobre a leitura atual, o envio do histórico só quando muda, o filtro por servidor, o modo de alertas, a abertura pela notificação, o botão voltar no dropdown, a troca de abas, o fim de cada aba (e dos estados vazios) acima da barra de abas com margem inferior de área segura, os ícones dos destinos (logotipos e bandeiras no menu, na etiqueta e em Ajustes), o filtro e o resumo por dia em Eventos, o limite por atalho e digitado (válido, inválido e fora da faixa, com o valor enviado em `configure`) e os erros nativos.
- `test/appearance_test.dart`: modo noturno. Cobre o padrão escuro, a troca pela barra superior e por Ajustes, a persistência em `darkMode`, as barras do sistema, o mostrador do anel em cada modo e a configuração inicial no modo salvo.
- `test/onboarding_test.dart`: configuração inicial. Cobre a exibição só na primeira abertura, a navegação entre passos, as escolhas salvas, o `start` com os argumentos escolhidos, o "Agora não" sem `start`, o limite digitado (bloqueio do "Continuar" com valor inválido e envio no `start`), o pulo da permissão do Wi-Fi e o reaproveitamento de ajustes antigos.
- `test/l10n_test.dart`: idiomas e doação. Cobre a resolução do idioma (sistema es/en/pt, idioma sem tradução caindo no inglês, escolha explícita), a configuração inicial no idioma do sistema, a escolha salva sobrepondo o sistema, a troca ao vivo em Ajustes e na boas-vindas (com persistência e volta ao "Sistema"), o `language` em `configure` e as chamadas a `setLanguage`, a tradução de textos nativos antigos e de eventos em es/en, o diagnóstico pelo `diagnosisCode`, a classificação de eventos em qualquer idioma, o botão de doação abrindo o link (plataforma do `url_launcher` simulada) e o toast de falha, o lembrete único, e todas as abas, Ajustes e o resumo da configuração inicial em espanhol e inglês numa tela de 360 dp sem estouro de layout. Os demais testes de tela fixam o português (`Locale('pt')` no `MaterialApp` ou no idioma do sistema simulado).
- `test/devices_test.dart`: aba Rede.
  - Leitura do escaneamento e do histórico, arredondamento que soma 100, presença por inventário, comparação presente/ausente, entrada antes de falhas e carga local.
  - Cenários: operadora (roteador bom), rede local (roteador lento e canal cheio), sinal fraco, aparelho correlacionado com as falhas, aparelhos só no histórico, verificações fora do Wi-Fi e teto dos pesos por tipo.
- `ConnectionMathTest.kt`: mediana, jitter, retransmissão, perda, classificação, códigos de diagnóstico (estáveis, sem repetição) e a dedução do código pelos textos antigos.
- `NotificationCardTest.kt`: cartão estável, instável e sem resposta como no desenho, frase da causa e há quanto tempo, barras das últimas verificações, faixa do Wi-Fi e escala do gráfico.
- `MonitorCardTest.kt`: textos (no idioma recebido) e cores por estado, nome da rede, formatação das métricas e faixa das últimas verificações por servidor.
- `WidgetFormatTest.kt`: cartão dos widgets monitorando, instável, sem internet, pausado e sem nenhuma medição, e o texto do widget pequeno.
- `AppLanguageTest.kt`: códigos de idioma e padrão do sistema; os três `strings.xml` têm as mesmas chaves e os mesmos marcadores (`%1$s`, `%1$d`), todo código de diagnóstico tem texto, e o português bate com o usado nos testes e na dedução dos textos antigos.
- `JsonLinesStoreTest.kt`: retenção de 24 h com intervalo de 1 min, linhas corrompidas, limpeza, criação do arquivo, teto de entradas e a política dos eventos (30 dias, 2000).
- `DeviceDiscoveryTest.kt`: partes puras da varredura da aba Rede.
  - Protocolos: SSDP (resposta, NOTIFY, M-SEARCH, host do LOCATION), descrição UPnP, NetBIOS (pedido e resposta, com e sem compressão, grupos, pacote inválido) e PTR (consulta e resposta).
  - Aparelhos: classificação dos tipos, fabricante, união por IP com prioridade de nome e limpeza de nomes.
  - Rede e Wi-Fi: estatísticas locais, hosts da sub-rede, canais, sobreposição, interferência e sugestão de canal.
- `DeviceInventoryStoreTest.kt`: inventários sem este aparelho e com retenção de 7 dias, medições do roteador e ida e volta do último escaneamento.
- `EventLogTest.kt`: formato da linha, ordem da mais recente para a mais antiga (inclusive no mesmo minuto), retenção de 30 dias, teto de 2000 e migração dos eventos antigos com o ano inferido.

O Gradle precisa de um JDK. Se `JAVA_HOME` não estiver definido, use o JDK do Android Studio (`C:\Program Files\Android\Android Studio\jbr`).

## Limitações conhecidas

- Mede acessibilidade e latência até o destino, não a velocidade de download ou upload.
- As mudanças de rede são detectadas no próximo ciclo, não instantaneamente (`NetworkCallback` ainda não é usado).
- Live Updates só existem no Android 16+. Em aparelhos Samsung dependem da versão da One UI.
- A exibição na tela de bloqueio depende das configurações do aparelho. Em Samsung, o padrão pode ser "somente ícones".
- Aba Rede:
  - Não mostra o consumo de banda por aparelho nem o MAC (limite do Android).
  - Aparelhos que não respondem a ping nem a TCP e não anunciam serviços ficam invisíveis; celulares dormindo podem sumir de um inventário.
  - A correlação usa só as 24 h de medições guardadas e depende do monitoramento ligado.
  - O IP serve de identidade: um aparelho que troca de IP vira outro.
- Apenas Android.
