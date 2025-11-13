# Refúgio de Guilda

Documentação estruturada do sistema de Refúgio controlável por guildas, cobrindo progressão, módulos, economia e interações PvE/PvP.

## Visão Geral
- **Refúgio**: área conquistável por guildas, composta por módulos (oficinas, fazenda, enfermaria etc.) e níveis que expandem slots, capacidade e bônus.
- **Ciclo principal**: conquistar → construir módulos → produzir/armazenar → defender hordas/raids → evoluir → expandir.
- **Recursos-chave**: madeira, metal, comida, remédios, combustível e energia (via gerador).

## NPC de Fundação
- **Isadora, Coordenadora do Abrigo**: localizada na área inicial, conduz a criação do primeiro refúgio.
- **Requisitos**: o jogador precisa ser líder (rank 3) de uma guilda ativa.
- **Tributo inicial**: 200 tábuas de madeira (`itemid: 5901`), 50 blocos de pedra (`itemid: 5880`) e 30 lingotes de metal (`itemid: 5887`).
- **Resultado**: registra a guilda como proprietária do Abrigo Inicial, grava a configuração no banco (`guild_refuges`) e carrega o mapa `data/world/refugio_inicial.otbm`, teletransportando o líder para a posição configurada.
- **Configuração dos refúgios**: toda a lista de abrigos e seus requisitos ficam centralizados em `data/lib/core/guild_refuges.lua`. Cada NPC que usa `refuge_keeper.lua` precisa informar o `refuge_key` correspondente no arquivo XML para ficar responsável apenas pelo seu abrigo.

## Evolução por Nível
| Nível | Nome | Requisitos para subir | Slots de módulo | Capacidade do armazém | Buffs / Safe Zone | Outros benefícios |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Abrigo | 200 madeira, 50 pedra | 2 | 200 itens | Safe zone 3×3; -5% chance de infecção | `/home`, logout seguro |
| 2 | Refúgio Reforçado | +500 madeira, +200 metal | 4 | 500 itens | Safe 5×5; -10% infecção; +1 guarda NPC | Craft básico |
| 3 | Base Fortificada | +800 metal, +800 comida | 6 | 900 itens | Safe 7×7; -15% infecção; 2 guardas | Oficina nível 2, enfermaria |
| 4 | Colônia | +1200 comida, +400 remédios | 8 | 1400 itens | Safe 9×9; -20% infecção; 3 guardas | Fazendinha, energia |
| 5 | Fortaleza | +1500 metal, +1500 recursos mistos | 10 | 2000 itens | Safe 11×11; -25% infecção | Recall interno e fast-travel entre bases aliadas (CD longo) |

**Safe Zone**: sem PvP, spawns de zumbi suprimidos e integração com o creaturescript de infecção para reduzir chance final.

## Módulos do Refúgio
Cada módulo ocupa 1 slot, possui níveis e consome recursos tanto para construção quanto para manutenção (upkeep a cada 10 min). Falhas no upkeep deixam o módulo offline até pagar a dívida.

| Módulo | Efeito | Custo nível 1 | Upkeep (10 min) | Escala por nível |
| --- | --- | --- | --- | --- |
| Armazém | Expande capacidade do cofre/itens | 200 madeira | 2 madeira | +200 capacidade por nível |
| Oficina | Crafting de armas brancas e munição | 150 madeira, 50 metal | 1 metal | Novas receitas por nível |
| Enfermaria | Cura DoT, cura percentual, vende soro | 100 madeira, 40 remédio | 1 remédio | -5% duração da infecção por nível |
| Fazendinha | Produz comida | 120 madeira | 2 água (item) | +5 comida/10 min/nível |
| Gerador | Fornece energia para módulos elétricos | 150 metal, 50 combustível | 5 combustível | +capacidade de "energia" por nível |
| Torreta | Defesa automática PvE | 200 metal | 2 munição (item) | +dano e alcance |
| Rádio | Desbloqueia missões/eventos dinâmicos | 80 metal | 0 | Mais eventos e melhores recompensas |
| Dormitório | +slots de bind `/home` | 100 madeira | 1 comida | +3 membros por nível |
| Mercador | Vende itens via influência | 100 metal, 100 comida | 0 | Catálogo escala com influência da guild |

## Permissões e Ranks da Guilda
- **Líder**: elevar nível do refúgio, instalar/remover módulos, ativar fast-travel e configurar impostos/taxas.
- **Oficiais**: coletar produção, iniciar defesas e abrir crafting compartilhado.
- **Membros**: usar enfermaria, crafting limitado e definir `/home`.
- **Aliados**: acesso a serviços básicos (configurável).

## Loops de Economia e Progressão
1. **Loot/Coleta** → recursos depositados no cofre do refúgio.
2. **Construção** → desbloqueia módulos e receitas.
3. **Upkeep** → mantém o refúgio e módulos online.
4. **Eventos** (rádio/hordas) → concedem influência para buffs, mercador e perks.
5. **Evolução** → amplia slots, segurança e mobilidade.

## Interações PvP/PvE
- **Hordas**: priorizam refúgios com maior influência (ou aleatório ponderado).
- **Raids de guild**: rivais podem desativar módulos destruindo núcleos interativos (soft-raid, sem destruir a base).
- **Influência**: defender hordas aumenta influência; falhas reduzem.

## Interface, Comandos e Fluxos
- `!refugio`: painel geral (nível, owner, slots, produção, upkeep pendente, próxima horda).
- `!construir <módulo>` / `!upar <módulo>` / `!remover <módulo>`: gerenciamento, sujeito a permissões e custos.
- `!coletar` ou `!coletar fazenda`: coleta produção de todos os módulos ou de um específico.
- `/bindhome` (dentro da safe zone da guild) e `/home` (CD 20 min).
- `/taxa <0–10%>`: define taxa sobre crafting/mercador que vai para o cofre.

## Fórmulas de Referência
- **Custo de upgrade (nível _n_)**: `custo_base * (1 + 0.35 * (n - 1))`, arredondado.
- **Produção da fazenda / 10 min**: `5 * nível * (1 + bônus_clima)` (chuva = +20%).
- **Redução de infecção**: `chance_final = max(0, chance_base - nivelRefugio * 0.05)` (máx. 25%).
- **Alcance da torreta**: `4 + nível` SQM; **Dano**: `20 + 15 * nível`.
