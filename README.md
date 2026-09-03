# Demonstração dos hooks do GitHub Copilot no VS Code

Este repositório demonstra os oito eventos de hooks disponíveis no **Copilot
Chat em Agent mode** no Visual Studio Code. Ele não é uma demonstração dos hooks
do Copilot CLI.

A configuração nativa fica em `.github/hooks/log-all-events.json`. Cada hook
recebe seu payload JSON pelo `stdin` e passa o nome do evento ao script de
logging. Há implementações equivalentes para os sistemas suportados:

- Windows: `.github/scripts/log-copilot-hook.ps1`
- Linux e macOS: `.github/scripts/log-copilot-hook.sh`

Cada execução acrescenta uma linha a `.github/logs/copilot-hooks.jsonl` no
formato:

```json
{"loggedAt":"2026-09-03T12:00:00.0000000+02:00","hook":"UserPromptSubmit","payload":{"session_id":"...","hook_event_name":"UserPromptSubmit","prompt":"..."}}
```

Os scripts não escrevem em `stdout` nem retornam decisões ao agente. Portanto,
esta demo apenas observa os eventos, sem alterar ou bloquear o comportamento do
Copilot.

> [!WARNING]
> O log pode conter prompts, caminhos, argumentos e resultados de ferramentas,
> além de outros dados sensíveis. O arquivo JSONL é ignorado pelo Git e não deve
> ser publicado. Não use este logging indiscriminado em produção.

## Eventos registrados

Todos os payloads incluem `timestamp` e `hook_event_name` e podem incluir `cwd`,
`session_id` e `transcript_path`. Os principais campos específicos são:

| Evento | Quando ocorre | Campos específicos |
| --- | --- | --- |
| `SessionStart` | No início de uma nova sessão, ao enviar o primeiro prompt | `source` |
| `UserPromptSubmit` | Ao enviar um prompt | `prompt` |
| `PreToolUse` | Antes de o agente invocar uma ferramenta | `tool_name`, `tool_input`, `tool_use_id` |
| `PostToolUse` | Depois de uma ferramenta concluir com sucesso | `tool_name`, `tool_input`, `tool_use_id`, `tool_response` |
| `PreCompact` | Antes da compactação do contexto da conversa | `trigger` |
| `SubagentStart` | Quando um subagente é iniciado | `agent_id`, `agent_type` |
| `SubagentStop` | Quando um subagente conclui | `agent_id`, `agent_type`, `stop_hook_active` |
| `Stop` | Quando a execução atual do agente termina | `stop_hook_active` |

`Stop` não significa que o chat foi fechado ou ficou inativo. Ele ocorre quando
a execução atual do agente termina, normalmente após concluir a resposta a um
prompt.

## Pré-requisitos

- Uma versão do VS Code e do GitHub Copilot que ofereça suporte a agent hooks.
- Acesso ao Copilot Chat em **Agent mode**.
- Hooks permitidos pelas políticas da organização.
- PowerShell no Windows ou Bash com `awk` no Linux e macOS.

Agent hooks ainda estão em **Preview**. O formato e o comportamento podem mudar,
e a organização pode desabilitar o recurso por política.

## Como executar a demonstração

1. Abra a raiz deste repositório no VS Code.
2. Abra o Copilot Chat e selecione **Agent** no seletor de modo.
3. Em outro terminal, acompanhe o arquivo de log:

   Windows:

   ```powershell
   Get-Content .github\logs\copilot-hooks.jsonl -Wait
   ```

   Linux ou macOS:

   ```bash
   tail -f .github/logs/copilot-hooks.jsonl
   ```

4. Inicie um chat novo e envie:

   ```text
   Explique em uma frase qual é o objetivo deste repositório.
   ```

   O primeiro prompt de um chat novo demonstra `SessionStart`,
   `UserPromptSubmit` e `Stop`.

5. Para demonstrar `PreToolUse` e `PostToolUse`, envie:

   ```text
   Liste os arquivos deste repositório e leia o README.md.
   ```

   Esses eventos podem aparecer várias vezes, uma vez para cada ferramenta
   utilizada. `PostToolUse` só ocorre quando a ferramenta conclui com sucesso.

6. Para tentar demonstrar `SubagentStart` e `SubagentStop`, envie:

   ```text
   Use um subagente para analisar este README e resumir os principais pontos.
   ```

   Esses eventos só ocorrem se o agente realmente delegar a tarefa a um
   subagente; a disponibilidade dessa capacidade depende do ambiente.

`PreCompact` normalmente só aparece quando a conversa cresce o suficiente para
que o VS Code compacte o contexto automaticamente. Não há uma ação manual
equivalente necessária para esta demo, então o evento pode não ocorrer durante
uma execução curta.

Agrupe os registros de uma conversa por `payload.session_id` e ordene-os por
`payload.timestamp`.

## Diagnóstico

Se nenhum registro for criado:

1. Confirme que a pasta aberta no VS Code é a raiz deste repositório.
2. Confira a execução dos hooks no canal de saída **GitHub Copilot Hooks**.
3. Execute **Developer: Show Agent Debug Logs** pela Paleta de Comandos.
4. Verifique se a política da organização permite hooks.
5. Salve novamente `.github/hooks/log-all-events.json`; o VS Code carrega
   alterações nos arquivos de hooks automaticamente.

Somente a configuração nativa deste arquivo deve permanecer ativa em
`.github/hooks/`. Manter também uma configuração compatível com o Copilot CLI
pode fazer eventos suportados serem executados duas vezes.

Consulte a documentação oficial:

- [Agent hooks no VS Code](https://code.visualstudio.com/docs/agent-customization/hooks)
- [Referência de hooks](https://code.visualstudio.com/docs/agents/reference/hooks-reference)
