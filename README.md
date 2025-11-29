# Reminder2Cal

🔔 Sincronize automaticamente seus Lembretes do macOS com seu Calendário.

## 📖 Sobre

Reminder2Cal é uma aplicação nativa para macOS que monitora seus Lembretes e automaticamente cria eventos no Calendário quando eles têm uma data/hora definida. Funciona silenciosamente na barra de menus, mantendo seus compromissos sempre sincronizados.

## ✨ Características

- 🔄 **Sincronização Automática**: Monitora mudanças em tempo real
- 📅 **Integração Nativa**: Usa as APIs nativas do macOS para Reminders e Calendar
- 🎯 **Menu Bar App**: Interface limpa e minimalista na barra de menus
- 🔐 **Privacidade**: Todos os dados ficam no seu Mac, sem cloud
- ⚡ **Performance**: Build otimizado com Swift nativo
- 🔒 **Seguro**: Code signing e hardened runtime

## 🔧 Requisitos

- macOS 14.0 (Sonoma) ou superior
- Xcode Command Line Tools
- Swift 5.9+

## 🚀 Build & Instalação

### Build Rápido

```bash
make app
```

### Instalação no /Applications

```bash
make install
```

### Executar

```bash
make run
```

### Desinstalar

```bash
make uninstall
```

## 📦 Build System

O projeto usa um Makefile avançado que replica as funcionalidades do Xcode:

### Targets Principais

| Target | Descrição |
|--------|-----------|
| `make all` | Build completo do app bundle (default) |
| `make app` | Cria o app bundle |
| `make build` | Compila o executável Swift |
| `make run` | Build e executa o app |
| `make clean` | Limpa artifacts de build |
| `make install` | Instala em /Applications |
| `make help` | Mostra todos os targets disponíveis |

### Targets Avançados

| Target | Descrição |
|--------|-----------|
| `make build-universal` | Build universal (Intel + Apple Silicon) |
| `make verify-signature` | Verifica assinatura do código |
| `make validate` | Valida estrutura do app bundle |
| `make dmg` | Cria DMG para distribuição |
| `make notarize` | Notariza o app pela Apple |
| `make release` | Build completo de release com notarização |
| `make analyze` | Análise estática do código |
| `make info` | Mostra informações do build |

### Desenvolvimento

```bash
# Build de debug
make debug

# Executar com output de debug
make run-debug

# Limpar tudo
make clean

# Limpar derived data
make clean-derived
```

### Versionamento

```bash
# Bump patch version (1.0.0 -> 1.0.1)
make bump-patch

# Bump minor version (1.0.0 -> 1.1.0)
make bump-minor

# Bump major version (1.0.0 -> 2.0.0)
make bump-major
```

## 📁 Estrutura do Projeto

```
reminder2cal/
├── Makefile              # Sistema de build
├── Package.swift         # Swift Package Manager
├── VERSION               # Versão do app
├── Info.plist           # Configuração do bundle
├── Entitlements.plist   # Permissões e hardened runtime
├── Build.xcconfig       # Configurações de build
├── icon.icns            # Ícone do app
├── Assets.xcassets/     # Asset catalog
└── Sources/
    ├── Reminder2Cal/        # App principal
    ├── Reminder2CalSync/    # Lógica de sincronização
    └── AppConfig/           # Configurações
```

## 🔐 Code Signing

O projeto está configurado com:
- **Developer ID Application** certificate
- **Hardened Runtime** habilitado
- **Entitlements** para Calendar e Reminders
- **Timestamp** para validade da assinatura

### Configurar Code Signing

1. Atualize `SIGNING_IDENTITY` no [`Makefile`](Makefile:24):
```makefile
SIGNING_IDENTITY := "Developer ID Application: Seu Nome (TEAM_ID)"
```

2. Para notarização, configure suas credenciais:
```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "seu@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

## 🎯 Workflow de Release

```bash
# 1. Atualizar versão
make bump-minor

# 2. Build completo e notarização
make release

# 3. Distribuir o DMG
# Reminder2Cal.dmg estará pronto
```

Ou passo-a-passo:

```bash
make clean              # Limpar builds anteriores
make app                # Build do app
make verify-signature   # Verificar assinatura
make dmg                # Criar DMG
make notarize          # Notarizar (requer configuração)
```

## 🔍 Validação

Verificar se o app está corretamente assinado e pronto para distribuição:

```bash
# Validar estrutura do bundle
make validate

# Verificar assinatura
make verify-signature

# Informações do build
make info
```

## 🛠 Desenvolvimento

### Requisitos de Desenvolvimento

```bash
# Verificar dependências
make check-deps
```

### Estrutura Modular

O projeto usa Swift Package Manager com módulos separados:

- **AppConfig**: Gerenciamento de configurações
- **Reminder2CalSync**: Lógica de sincronização
- **Reminder2Cal**: Interface e app principal

### Adicionar Novas Features

1. Edite os arquivos em `Sources/`
2. Build: `make build`
3. Teste: `make run-debug`
4. Valide: `make validate`

## 📄 Licença

Copyright © 2025 Marcus Grando. All rights reserved.

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📞 Suporte

Para problemas ou sugestões, abra uma issue no GitHub.

## 📚 Documentação Adicional

- [`BUILD_IMPROVEMENTS.md`](BUILD_IMPROVEMENTS.md) - Detalhes das melhorias no build system
- [`Info.plist`](Info.plist) - Configuração do app bundle
- [`Entitlements.plist`](Entitlements.plist) - Permissões e segurança

## 🎨 Ícones

Ícones disponíveis em [CandyIcons](https://www.flaticon.com/packs/candy-icons).

---

**Feito com ❤️ em Swift**