# Linkzora · board de melhorias

Quadro de acompanhamento. Os itens nunca são apagados: andam de **To do** para **Doing** e depois para **Done**.
Datas no formato AAAA-MM-DD.

## To do

- [ ] Validar o primeiro envio automático do `distribute.yml` depois do merge do PR #1 em `master` (o GitHub só roda workflows manuais que já existam na branch principal).

## Doing

## Done

### Iteração 6 · 2026-10-17

- [x] Transformar este arquivo em um board de To do, Doing e Done sem perder os registros.
- [x] Notificação fixa conforme a imagem enviada no chat (`design/notificacao/notificacao-redesign.png`), com os comportamentos de cada estado (estável, instável e sem resposta): cartão próprio até o Android 15 e ProgressStyle (Live Update) no Android 16+. *(prioritária)*
- [x] Widget: trocar o ícone do Wi-Fi pelo ícone do app e mostrar o nome do Wi-Fi (também quando o serviço volta sozinho após boot ou atualização).
- [x] Pipeline de distribuição pelo Firebase App Distribution: projeto `linkzora-app`, grupo `testers`, workflow `distribute.yml`, assinatura de release fixa e primeira versão publicada.
- [x] CI atualizado (`android.yml`): não roda mais `flutter create` sobre o projeto; roda análise, testes Flutter e JVM e gera o APK.
- [x] Conta de serviço `github-distribution` no projeto `linkzora-app` com o papel Firebase App Distribution Admin; chave salva no secret `FIREBASE_SERVICE_ACCOUNT` (cópia local apagada).
- [x] Atualizar as documentações com o que foi feito nas últimas iterações e nesta.
- [x] Corrigir bugs de fluxo, contexto, UI, strings e localizações faltantes; atualizar testes: nome do Wi-Fi sumindo quando o serviço volta sozinho (boot/atualização), legenda da notificação cortada, "Sem conexão" repetido, resumo do setup inicial cortado; traduções ES/EN conferidas (nenhuma chave faltando, Flutter e nativo); testes do novo cartão (`NotificationCardTest`). *(último, menos prioritário)*

### Iteração 5 · 2026-10-16 · revisão e correções

- [x] Procurar bugs de fluxo e contexto e corrigir: eventos duplicados a cada reinício do serviço, título antigo "Conexão lenta" contado como estável, ícone colorido sumido das notificações, possível falha ao iniciar o serviço em segundo plano no Android 14+, consulta ao serviço a cada segundo com o app minimizado.
- [x] Monitoramento volta sozinho após reiniciar o aparelho ou atualizar o app.
- [x] "74ms" → "74 ms" nos eventos (inclusive nos antigos).
- [x] Commit, push (branch `feat/linkzora-app`, PR #1) e resolução do conflito com `master`.

### Iteração 4 · 2026-10-16

- [x] Ajustar ícones do filtro de servidores (pode usar lib externa para ícones bonitos).
- [x] Corrigir bug de scroll (presente em todas as abas): as abas ficavam em cima dos ícones.
- [x] Modo diurno: o branco do círculo central estava destoado e com margem.
- [x] Eventos (última aba): estão sendo salvos? resetam? qual seria o melhor? tem filtro por dia?
- [x] Criar uma aba separada para identificar os dispositivos da rede que estão causando problemas, seguindo a análise feita, com o percentual de cada dispositivo conforme regras próprias.
- [x] Mudar o ícone do app para o enviado no chat.
- [x] Criar versão de widget (para a tela inicial).
- [x] Criar uma seção de doação ("pague-me um cafezinho") com o link https://buymeacoffee.com/andremaracaja e uma mensagem como "gostando do app, que tal pagar um cafezinho pra esse dev ;)".
- [x] Criar arquivos de internacionalização para PT, ES e EN, com bandeirinhas para trocar o idioma (detectando o do sistema como padrão) e no setup inicial.

### Iteração 3 · 2026-10-16

- [x] Criar uma página de configuração inicial, que só roda na primeira abertura do app e salva as escolhas (servidor, alertas etc.).
- [x] Ajustar a notificação para o visual desenhado enviado no chat.
- [x] Melhorar o visual das abas e do topbar.
- [x] Criar modo noturno on/off.
- [x] Ajustar o limite (opção de entrada manual) começando de 30, 60, 80, 100, 200, 300, 400, 500…
- [x] Na notificação, remover o ícone do app à direita para usar todo o espaço; trocar o tracejado por uma linha contínua.

### Iteração 2 · 2026-10-16

- [x] Permitir ao usuário escolher os alertas de mudança: não notificar, notificar uma vez por sessão de monitoramento ou notificar a cada mudança.
- [x] Melhorar o cartão de monitoramento para incluir a escolha de alertas sem deixá-lo grande ou visualmente pesado.
- [x] Fazer os ícones das notificações refletirem o ícone do app.
- [x] A aba Monitoria precisa ser por servidor: manter o estado apenas por servidor; se o servidor mudar, o gráfico muda também.
- [x] Melhorar o gráfico (pode usar libs externas); precisa ser diferente e bonito, o anterior estava muito simples.
- [x] Ícone da notificação estava no lugar errado, em dois lugares; deixar o colorido ao lado do nome.
- [x] Notificação fixa também na tela de bloqueio (Live Update).
- [x] Filtro de servidor como um dropdown bonito; mudar também o modal de seleção de alerta para o visual do app.
- [x] Revisar o app e ajustar a UI ao novo padrão visual; verificar se os cálculos do serviço fazem sentido e melhorá-los.
- [x] Ajustar visualmente as notificações fixas e as push notifications, deixando-as modernas.
- [x] Verificar se faltam testes importantes.
- [x] Criar uma documentação sobre as funcionalidades e o contexto do aplicativo.
- [x] Verificar bugs e corrigir.

### Iteração 1 · 2026-10-16

- [x] Colocar temporizador na tela de quanto tempo falta até a próxima verificação (apenas na home), abaixo do círculo, mais à direita.
- [x] Mudar o ícone e o título de "Proteção da conexão" para indicar monitoramento.
- [x] Criar uma aba de monitoria, informando períodos de falhas, gráfico de oscilação e melhor período de uso da internet.
- [x] Identificar causas prováveis para a conexão ruim usando disponibilidade, falhas, jitter, distância do servidor e sinal Wi-Fi. O diagnóstico é apresentado como provável porque o app não enxerga a infraestrutura interna da operadora.
- [x] Na aba de monitoria, dividir as conexões por servidor, informando se aquele período foi para um servidor na Europa etc.
- [x] Mudar o nome do aplicativo para Linkzora.
- [x] Colocar na home qual servidor está em uso (tag semelhante à do temporizador, no canto superior esquerdo e adaptável ao tamanho do nome).
- [x] Na aba Monitoria, também mostrar no item o problema, ainda que seja uma causa provável.
- [x] Mudar o ícone para o enviado no chat e torná-lo o ícone do aplicativo.
- [x] Criar uma splash screen apenas com o ícone enviado e um loading; durante o loading, fazer a primeira verificação e abrir a home com o primeiro dado.
