/*
  バリデーション関数モジュール

  設定値の型チェック用ヘルパー関数を提供します。
  各関数は検証に失敗した場合、エラーメッセージと共にthrowします。
  shared/config.nixおよびshared/sections/*.nixから利用されます。
*/
let
  # 基本バリデーション関数
  assertType =
    name: value: predicate: message:
    if predicate value then
      value
    else
      throw "Config validation error for '${name}': ${message}. Got: ${builtins.toJSON value}";

  # 述語関数
  isValidIP = ip: builtins.match ''^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'' ip != null;
  isValidPort = port: builtins.isInt port && port >= 1 && port <= 65535;
  isValidCIDR =
    cidr: builtins.match ''^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$'' cidr != null;
  isValidPath = path: builtins.isString path && builtins.substring 0 1 path == "/";
  isValidEmail = email: builtins.match "^[^@]+@[^@]+" email != null;
in
{
  # 基本関数（カスタム述語用）
  inherit assertType;

  # 型別ショートカット
  assertString = name: value: assertType name value builtins.isString "Must be a string";

  assertBool = name: value: assertType name value builtins.isBool "Must be a boolean";

  assertPort = name: value: assertType name value isValidPort "Must be a valid port number (1-65535)";

  assertIP = name: value: assertType name value isValidIP "Must be a valid IP address";

  assertCIDR = name: value: assertType name value isValidCIDR "Must be a valid CIDR notation";

  assertPath = name: value: assertType name value isValidPath "Must be an absolute path";

  assertEmail =
    name: value:
    assertType name value (e: builtins.isString e && isValidEmail e) "Must be a valid email address";

  assertPositiveInt =
    name: value: assertType name value (n: builtins.isInt n && n > 0) "Must be a positive integer";

  assertNonNegativeInt =
    name: value: assertType name value (n: builtins.isInt n && n >= 0) "Must be a non-negative integer";

  assertEnum =
    name: value: allowed:
    assertType name value (v: builtins.elem v allowed)
      "Must be one of: ${builtins.concatStringsSep ", " (map (x: "'${x}'") allowed)}";

  assertListOf =
    name: values: assertFn:
    map (value: assertFn name value) values;
}
