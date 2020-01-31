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

### (Option)VirtualBox guest addition plugin

VirtualBoxの仮想マシンにゲスト拡張を自動で追加してくれるプラグインです。
このタイミングでこのプライグインを入れておくと、仮想マシンとホストマシン間の共有ディレクトリ設定を後々楽にできます。

```shell
vagrant plugin install vagrant-vbguest
```

# ローカルマシンでサービスを試す

## 仮想マシンの作成と起動

ターミナルを開き、Vagrantを使って仮想マシンを構築します。
Windowsの方は[Windows Terminal](https://www.microsoft.com/ja-jp/p/windows-terminal-preview/9n0dx20hk701?activetab=pivot:overviewtab)や[Cmder](https://cmder.net)などコマンドプロンプト(cmd.exe)より高機能なターミナルを使うことをお勧めします。

Vagrantfile があるフォルダに移動し、仮想マシンのベースとなるマシンイメージ(box)を取ってきて起動します。
初回はVagrant Cloud(boxの共有サイト)からダウンロードしてきます。[^1]
2回目以降は取得済みのboxを再利用します。

```shell
cd .¥path¥to¥this¥repo
vagrant up
```

次回仮想マシンを起動するときも `vagrant up` でOKです。仮想マシンが作り直されることはありません。

[^1]: マシンイメージはダウンロードサイズが大きいため、通信料が従量課金のネットワークではやめた方がいいでしょう。

**vagrant upでエラーがでたら**

[VirtualBox で Failed to open/create the internal network 'HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter' が出た時の対処](https://qiita.com/ExA_DEV/items/ae80a7d767144c2e1992)

## 仮想マシンにサービスをデプロイ

仮想マシンが起動したら、startup.shに従ってサービスをデプロイします。[^2]

[^2]: ソフトウェアのダウンロードサイズが大きいため、通信料が従量課金のネットワークではやめた方がいいでしょう。

```shell
vagrant provision
```

ブラウザで[Testlink](http://192.168.2.200:3001)と[Redmine](http://192.168.2.200:3000)が起動していることを確認しましょう。

**vagrant provisionでエラーが出たら**

Timeoutエラーが出たら、もう一度 vagrant provision をやり直してみてください。

```shell
    default: Error: Error downloading packages:
    default:   Curl error (28): Timeout was reached for http://mirrorlist.centos.org/?release=8&arch=x86_64&repo=BaseOS&infra=vag [Connection timed out after 30001 milliseconds]
    default: + exit 1
The SSH command responded with a non-zero
```

```shell
    default: + dnf install -y expect
    default: CentOS-8 - AppStream                            8.9 kB/s | 4.3 kB     00:00
    default: CentOS-8 - Base                                 5.4 kB/s | 3.8 kB     00:00
    default: CentOS-8 - Extras                               0.0  B/s |   0  B     00:36
    default: Failed to download metadata for repo 'extras'
    default: Error: Failed to download metadata for repo 'extras'
    default: + exit 1
```

## サービスを触ってみる

[Testlink日本語化プロジェクト](https://w.atwiki.jp/testlink/pages/25.html)や[Redmine.jp](http://redmine.jp)を参考にサービスを使ってみてください。

**エラーが出たら**

`setenforce 0`

```shell
Jan 31 19:11:26 localhost dbus-daemon[606]: [system] Activating service name='org.fedoraproject.Setroubleshootd' requested by ':1.137' (uid=0 pid=533 comm="/usr/sbin/sedispatch " label="system_u:system_r:auditd_t:s0") (using servicehelper)
Jan 31 19:11:28 localhost dbus-daemon[606]: [system] Successfully activated service 'org.fedoraproject.Setroubleshootd'
Jan 31 19:11:29 localhost setroubleshoot[6711]: failed to retrieve rpm info for /var/lib/redmine/config.ru
```

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
