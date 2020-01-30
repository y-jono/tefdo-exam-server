# このリポジトリについて

このリポジトリはテストケースを管理するためのサービスである[TestLink](http://testlink.org)と、バグを管理するサービスである[Redmine](https://www.redmine.org)を作成できます。
プロビジョニングスクリプト`startup.sh`を使うとTestlinkサービスとRedmineサービスを提供するサーバーを作成できます。

利用ツール: Vagrant
OS: CentOS 8
デプロイターゲット: VirtualBox(仮想マシン), Vultr(VPSサービス)

# Vagrant

Vagrantは仮想マシンをターミナルからコマンドで操作するためのクライアントです。
LinuxOSがインストールされたサーバーを手元のマシンに作成し、上のサービスをデプロイする為に使います。

## インストール

[ダウンロードページ](https://www.vagrantup.com/downloads.html)から手元のOSにあうインストーラーをダウンロードしてください。
インストール時にVirtualBoxが同時にインストールします。
既にマシンにVirtualBoxがインストール済みの方はご注意ください。
VagrantとVirtualBoxのバージョンは組み合わせがあります。
うまく動かない時は[このページ](https://qiita.com/lunar_sword3/items/682fdd39c57a2319b83f)を参考にしてください。

### (Option)VirtualBox guest addtion plugin

VirtualBoxの仮想マシンにゲスト拡張を自動で追加してくれるプラグインです。
このタイミングでこのプライグインを入れておくと、仮想マシンとホストマシン間の共有ディレクトリ設定を後々楽にできます。

```shell
vagrant plugin install vagrant-vbguest
```

# ローカルマシンでサービスを試す

## 仮想マシンの作成と起動

ターミナルを開き、Vagrantを使って仮想マシンを構築します。
Windowsの方は[Windows Terminal](https://www.microsoft.com/ja-jp/p/windows-terminal-preview/9n0dx20hk701?activetab=pivot:overviewtab)や[Cmder](https://cmder.net)などコマンドプロンプト(cmd.exe)より高機能なターミナルを使うことをお勧めします。

Vagrantfile があるフォルダに移動し、仮想マシンのベースとなるマシンイメージを取ってきて起動します。

```shell
cd .¥path¥to¥this¥repo
vagrant up
```

次回仮想マシンを起動するときも `vagrant up` でOKです。仮想マシンが作り直されることはありません。

## 仮想マシンにサービスをデプロイ

仮想マシンが起動したら、startup.shに従ってサービスをデプロイします。

```shell
vagrant provision
```

ブラウザで[Testlink](http://192.168.2.200:3001)と[Redmine](http://192.168.2.200:3000)が起動していることを確認しましょう。

## サービスを触ってみる

[Testlink日本語化プロジェクト](https://w.atwiki.jp/testlink/pages/25.html)や[Redmine.jp](http://redmine.jp)を参考にサービスを使ってみてください。

## 仮想マシンを停止する

用がなくなったら仮想マシンを停止しましょう。自らコマンドで停止しない場合、VirtualBoxのプロセスはOSが適当なタイミングで止めるようです。

```shell
vagrant halt
```

# (Option)VPS(Vultr)でサービスを公開する

WIP

```shell
vagrant plugin install vagrant-vultr
```

[参考ページ](https://www.vultr.com/docs/using-vultr-as-your-vagrant-provider)
