let
  NGINX_ROOT = "/home/m1nd/Projekte/devenv/typo3/public/";
  NGINX_PORT = "8080";
  MYSQL_USER = "admin";
  MYSQL_PW = "M4n4";
in
{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "typo3-devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.php81 ];
  # https://devenv.sh/scripts/
  scripts.hello.exec = "echo hello from $GREET";

  enterShell = ''
    hello
    php --version
  '';

  # PHP configuration
  languages.php.enable = true;
  languages.php.package = pkgs.php83.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [
      pdo
      session
      filter
      tokenizer
      mbstring
      intl
    ];
    extraConfig = ''
      memory_limit=256m
      max_execution_time=240
      max_input_vars=1500
      post_max_size=10M
      upload_max_filesize = 10M
      pcre.jit=1 
    '';
  };
  languages.php.fpm.pools.web = {
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
    };
  };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep "2.42.0"
  '';
services.mysql.enable = true;
services.mysql.initialDatabases = [{ name = "typo3"; }];
   services.mysql.ensureUsers = [
     {
       name = ''${MYSQL_USER}'';
       password = ''${MYSQL_PW}'';
       ensurePermissions = { "typo3.*" = "ALL PRIVILEGES"; };
     }
   ];

  # https://devenv.sh/services/
  services.nginx.enable = true;
  services.nginx.httpConfig = ''
    server {
      listen ${NGINX_PORT};
      root ${NGINX_ROOT};
      index index.php;
      location ~ \.js\.gzip$ {
        add_header Content-Encoding gzip;
        gzip off;
        types { text/javascript gzip; }
      }

      location ~ \.css\.gzip$ {
          add_header Content-Encoding gzip;
          gzip off;
          types { text/css gzip; }
      }

      # TYPO3 - Rule for versioned static files, configured through:
      # - $GLOBALS['TYPO3_CONF_VARS']['BE']['versionNumberInFilename']
      # - $GLOBALS['TYPO3_CONF_VARS']['FE']['versionNumberInFilename']
      if (!-e $request_filename) {
          rewrite ^/(.+)\.(\d+)\.(php|js|css|png|jpg|gif|gzip)$ /$1.$3 last;
      }

      # TYPO3 - Block access to composer files
      location ~* composer\.(?:json|lock) {
          deny all;
      }

      # TYPO3 - Block access to flexform files
      location ~* flexform[^.]*\.xml {
          deny all;
      }

      # TYPO3 - Block access to language files
      location ~* locallang[^.]*\.(?:xml|xlf)$ {
          deny all;
      }

      # TYPO3 - Block access to static typoscript files
      location ~* ext_conf_template\.txt|ext_typoscript_constants\.txt|ext_typoscript_setup\.txt {
          deny all;
      }

      # TYPO3 - Block access to miscellaneous protected files
      location ~* /.*\.(?:bak|co?nf|cfg|ya?ml|ts|typoscript|tsconfig|dist|fla|in[ci]|log|sh|sql|sqlite)$ {
          deny all;
      }

      # TYPO3 - Block access to recycler and temporary directories
      location ~ _(?:recycler|temp)_/ {
          deny all;
      }

      # TYPO3 - Block access to configuration files stored in fileadmin
      location ~ fileadmin/(?:templates)/.*\.(?:txt|ts|typoscript)$ {
          deny all;
      }

      # TYPO3 - Block access to libraries, source and temporary compiled data
      location ~ ^(?:vendor|typo3_src|typo3temp/var) {
          deny all;
      }

      # TYPO3 - Block access to protected extension directories
      location ~ (?:typo3conf/ext|typo3/sysext|typo3/ext)/[^/]+/(?:Configuration|Resources/Private|Tests?|Documentation|docs?)/ {
          deny all;
      }

      location / {
        try_files $uri $uri/ /index.php$is_args$args;
      }
      
      location = /typo3 {
          rewrite ^ /typo3/;
      }

      location /typo3/ {
          absolute_redirect off;
          try_files $uri /typo3/index.php$is_args$args;
      }

      location ~ [^/]\.php(/|$) {
          fastcgi_split_path_info ^(.+?\.php)(/.*)$;
          if (!-f $document_root$fastcgi_script_name) {
              return 404;
          }
          fastcgi_buffer_size 32k;
          fastcgi_buffers 8 16k;
          fastcgi_connect_timeout 240s;
          fastcgi_read_timeout 240s;
          fastcgi_send_timeout 240s;

          # this is the PHP-FPM upstream - see also: https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/#connecting-nginx-to-php-fpm
          fastcgi_pass         unix:${config.languages.php.fpm.pools.web.socket};
          fastcgi_index        index.php;
          include ${config.services.nginx.package}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
      } 
        }
  '';


  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # https://devenv.sh/processes/
  # processes.ping.exec = "ping example.com";

  # See full reference at https://devenv.sh/reference/options/
}
