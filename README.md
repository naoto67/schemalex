### はじめに

こんにちは。現在アプリボットで内定者バイトをしている伊藤です。
今回は、schemalexを使用したマイグレーションファイルの自動生成の手法について紹介したいと思います。

[今回利用するリポジトリ](https://github.com/naoto67/schemalex.git)

### 導入背景

現在担当しているプロジェクトは絶賛開発段階で、MySQLのスキーマは変更される度にDBをリセットしています。
つまりマイグレーション管理が必要ない状態です。
しかし今後リリースした後には毎回リセットするわけにはいかないので、
今回リリース後に必要となるマイグレーションファイルを自動で生成するツールを作成することになりました。

### 構成

今回は以下のようなディレクトリを想定しており、`init/1_main.up.sql` に変更を加えていくと自動でmigration以下にその差分のSQLが生成されるものを作成していきます。
マイグレーションツールには、golang-migrateを使用します。

```
├── init
│   └── 1_main.up.sql
└── migration
    ├── xxxx_migration_gen.up.sql
    ├── xxxx_migration_gen.up.sql

    ︙

    └── xxxx_migration_gen.up.sql
```

### Schemalexについて

[schemalex](https://github.com/schemalex/schemalex)

> This tool can be used to generate the difference, or more precisely, the statements required to migrate from/to, between two MySQL schema.
>> 2つのMySQLのスキーマからマイグレーションに必要な差分を生成するツール

このSchemelexに渡すスキーマには、ローカルファイルやMySQLのデータソースなどが指定できる。

### 前準備

初期のDBのスキーマと、マイグレーション用のMySQLコンテナを用意しておきます。

`ddl/init/1_main.up.sql`

```sql
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  `id` BIGINT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT "1970-01-01 00:00:00",
  `updated_at` DATETIME(3) NOT NULL DEFAULT "1970-01-01 00:00:00",
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARACTER SET utf8mb4;
```

`docker-compose.yml`

```yml
version: '3'
services:
  db:
    image: mysql:5.7
    environment:
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
      - TZ='Asia/Tokyo'
    ports:
      - 13306:3306
```

### 実装

1. MySQLコンテナに `ddl/migration` 以下のマイグレーションファイルを使用してマイグレーションを実行
2. コンテナのDBをダンプ（golang-migrate で生成されるschema_migrationsを除外）
3. schemadiff を使用して `ddl/init/1_main.up.sql` と ダンプしたファイルを比較
4. 比較結果から新たなマイグレーションファイルを作成

#### ソースコード

```bash
#! /bin/bash

set -eu

mysql -uroot -h 0.0.0.0 -P 13306 < ./ddl/default.sql

migrations=`find ddl/migration -type f -name \*.up.sql | wc -l`
if [ $migrations -ne "0" ]; then
  yes | migrate -path ddl/migration -database "mysql://root:@tcp(localhost:13306)/migration" up
fi

docker-compose exec db mysqldump -uroot \
  -d migration \
  --ignore-table="migration.schema_migrations" > dump.sql

diff=`schemadiff -t=false dump.sql ./ddl/init/1_main.up.sql`

if [ -n "$diff" ]; then
  echo $diff > ddl/migration/$(date +%s)_migration_gen.up.sql
fi

rm dump.sql
```

#### 結果1

実行前

```bash
├── init
│   └── 1_main.up.sql
└── migration
```

`ddl/init/1_main.up.sql` を変更せずに実行

```bash
.
├── init
│   └── 1_main.up.sql
└── migration
    └── 1607881859_migration_gen.up.sql
```

```1607881859_migration_gen.up.sql
CREATE TABLE `users` ( `id` BIGINT (20) NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00', `updated_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00', PRIMARY KEY (`id`) ) ENGINE = InnoDB, DEFAULT CHARACTER SET = utf8mb4;
```

#### 結果2

結果1の後に `ddl/init/1_main.up.sql` を以下の様に変更して実行

```ssql
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  `id` BIGINT NOT NULL DEFAULT 0,
  `name` VARCHAR(256), // <- カラムの追加
  `created_at` DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
  `updated_at` DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARACTER SET utf8mb4;

// テーブル追加
DROP TABLE IF EXISTS user_items;
CREATE TABLE user_items (
  `id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARACTER SET utf8mb4;
```


```bash
├── init
│   └── 1_main.up.sql
└── migration
    ├── 1607881859_migration_gen.up.sql
    └── 1607882077_migration_gen.up.sql
```

```1607882077_migration_gen.up.sql
CREATE TABLE `user_items` ( `id` BIGINT (20) NOT NULL DEFAULT 0, PRIMARY KEY (`id`) ) ENGINE = InnoDB, DEFAULT CHARACTER SET = utf8mb4; ALTER TABLE `users` ADD COLUMN `name` VARCHAR (256) DEFAULT NULL AFTER `id`;
```

### まとめ

2つの異なるスキーマからマイグレーションファイルを自動生成する手法を紹介しました。
今回はサラッと紹介するためにシェルスクリプトのみでの実装になりましたが、実際のプロジェクトコードでは `github.com/urfave/cli` を使用してgoのツールとして作成しています。
そちらでは、今回割愛した生成されるSQLのフォーマット機能や、ファイル名をUnixTimeではなく10001, 10002のように連番で出力する機能だったりを追加で実装しています。
schemalex大変使い心地がよかったので、ぜひ試してみてください！

### おまけ

自動生成のコードからは割愛しましたが、 `schemalex` の中にはLint機能を持ったツールもあります。

```bash
$ cat sql.sql
CREATE TABLE `users` ( `id` BIGINT (20) NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00', `updated_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00', PRIMARY KEY (`id`) ) ENGINE = InnoDB, DEFAULT CHARACTER SET = utf8mb4;

$ schemalint sql.sql
CREATE TABLE `users` (
  `id` BIGINT (20) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  `updated_at` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  PRIMARY KEY (`id`)
) ENGINE = InnoDB, DEFAULT CHARACTER SET = utf8mb4;%
```

この `schemalint` は ALTER文が含まれているものに対しては、うまく動作しないためそのまま導入するのは少し難しいと思ってます。
まとめに、プロジェクトコードにはフォーマット機能が入っているという話をしましたが、そこではこの `schemalint` を使用していますが、文字列走査をしてから CREATE文のみ `schemalint` に流すといった形を取っています。
LinterはLinterで完結させたいなと少し思っているので、なにか良いツールがあれば教えていただけると助かります！
