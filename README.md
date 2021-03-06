# このリポジトリについて

このリポジトリはテストケースを管理するためのサービスである[TestLink](http://testlink.org)と、バグを管理するサービスである[Redmine](https://www.redmine.org)を作成できます。
プロビジョニングスクリプト`startup.sh`を使うとTestLinkサービスとRedmineサービスを提供するサーバーを作成できます。

- 利用ツール: Vagrant
- OS: CentOS 8
- デプロイターゲット: VirtualBox(仮想マシン), Vultr(VPSサービス)

# Vagrant

Vagrantは仮想マシンをターミナルからコマンドで操作するためのクライアントです。
LinuxOSがインストールされたサーバーを手元のマシンに作成し、上のサービスをデプロイする為に使います。

## インストール

[ダウンロードページ](https://www.vagrantup.com/downloads.html)から手元のOSにあうインストーラーをダウンロードしてください。

**vagrantをインストールする前に**

2020/2/5現在、 vagrant 2.2.7 のインストール及びアンインストールが失敗する現象がみられます。
この後のvbguestプラグインインストールもうまくいかないようです。
以下のリンクにある 2.2.6 でこのチュートリアルがうまくいくことを確認しているので、代わりに使ってください。

https://releases.hashicorp.com/vagrant/2.2.6/


インストール時にVirtualBoxが同時にインストールします。
既にマシンにVirtualBoxがインストール済みの方はご注意ください。
VagrantとVirtualBoxのバージョンは組み合わせがあります。
うまく動かない時は[このページ](https://qiita.com/lunar_sword3/items/682fdd39c57a2319b83f)を参考にしてください。

### VirtualBox guest addition plugin

VirtualBoxの仮想マシンにゲスト拡張を自動で追加してくれるプラグインです。
このタイミングでこのプライグインを入れておくと、仮想マシンとホストマシン間の共有ディレクトリ設定を後々楽にできます。

```shell
vagrant plugin install vagrant-vbguest
```


# VirtualBox

仮想マシン環境を動かすツールとしてVirtualBoxを利用します。
非商用目的であればVMWareを使うことも可能です（この場合は有償なので[ここ](https://www.vagrantup.com/vmware/#buy-now)から購入する）

VagrantとVirtualBoxはバージョンをうまく組み合わせる必要があります。
2020/2/5現在、 6.0系の最新である6.0.16を使うのが無難です。

https://www.virtualbox.org/wiki/Download_Old_Builds_6_0


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

**virtualbox guest additionをインストールする**

ホストと仮想マシンのネットワークアダプタをつなぐために、VirtualBox Guest Additions を仮想マシンにインストールします。
既に vagrant-vbguest をインストール済みなので、下記のコマンドで仮想マシンを再起動するだけでインストールできます。

```shell
cd .¥path¥to¥this¥repo
vagrant reload
```

**vagrant upでエラーがでたら**

[VirtualBox で Failed to open/create the internal network 'HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter' が出た時の対処](https://qiita.com/ExA_DEV/items/ae80a7d767144c2e1992)

```shell
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["startvm", "6edd0a17-66ed-4c51-9fc2-17633dc6a25c", "--type", "headless"]

Stderr: VBoxManage.exe: error: Failed to open/create the internal network 'HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter #2' (VERR_INTNET_FLT_IF_NOT_FOUND).
VBoxManage.exe: error: Failed to attach the network LUN (VERR_INTNET_FLT_IF_NOT_FOUND)
VBoxManage.exe: error: Details: code E_FAIL (0x80004005), component ConsoleWrap, interface IConsole
```

ホーム　ネットワークとインターネット　状態　アダプターのオプションを変更する
対象のネットワークアダプターについて、IPv6のオプションを外し、無効ー有効と変更する。

## 仮想マシンにサービスをデプロイ

仮想マシンが起動したら、startup.shに従ってサービスをデプロイします。[^2]

[^2]: ソフトウェアのダウンロードサイズが大きいため、通信料が従量課金のネットワークではやめた方がいいでしょう。

```shell
cd .¥path¥to¥this¥repo
vagrant provision
```

provisionが無事に終了すると、mysql, testlinkのユーザ名とパスワードが画面に出力されます。忘れずメモしてください。
このあとTestLinkのセットアップやphpMyAdminへのログインで使います。

ブラウザで[TestLink](http://192.168.2.200:3001)と[phpMyAdmin](http://192.168.2.200:3002)が起動していることを確認しましょう。

**ブラウザに何も表示されなかったら**

ホストとゲスト（仮想マシン）の間が通信できていますか？確認して、繋がっていなければ仮想マシンの再起動を試してみてください。

```shell
# ホストのshell
ping 192.168.2.200
# 繋がっていないことがわかったら仮想マシンを再起動
vagrant reload
```

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

- [TestLink日本語化プロジェクト](https://w.atwiki.jp/testlink/pages/25.html)
- [Redmine.jp](http://redmine.jp)
- [Redmineデフォルトデータのロード](http://redmine.jp/tech_note/first-step/admin/load_default_data/)
- [phpMyAdmin(DBの内容確認用)](https://docs.phpmyadmin.net/ja/latest/)

**redmineが動かないことがあったら**

SELinuxが原因で動かないことがあります。 `setenforce 0` で一旦無効にして OFF にしたら動作するかを確かめてみましょう。



## 仮想マシンを停止する

用がなくなったら仮想マシンを停止しましょう。自らコマンドで停止しない場合、VirtualBoxのプロセスはOSが適当なタイミングで止めるようです。

```shell
cd .¥path¥to¥this¥repo
vagrant halt
```

## 仮想マシンが必要ないなと思ったら

仮想マシンを使わないと確信したら、マシンごと削除しましょう。

```shell
cd .¥path¥to¥this¥repo
vagrant destroy
```

## Vagrantのアンインストール

Vagrantを使わないと確信したら、削除してしまいましょう。

[Uninstalling Vagrant](https://www.vagrantup.com/docs/installation/uninstallation.html)

# (Option)VPS(Vultr)でサービスを公開する

WIP

```shell
vagrant plugin install vagrant-vultr
```

[参考ページ](https://www.vultr.com/docs/using-vultr-as-your-vagrant-provider)
