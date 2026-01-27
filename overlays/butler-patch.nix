self: super: {
  butler = super.butler.overrideAttrs (old: {
    postConfigure =
      (old.postConfigure or "")
      + ''
        # Fix sevenzip-go signature mismatch (butler fails to build otherwise).
        if [ -f vendor/github.com/itchio/sevenzip-go/sz/glue.c ]; then
          substituteInPlace vendor/github.com/itchio/sevenzip-go/sz/glue.c \
            --replace 'out_stream_get_def_(os)' 'out_stream_get_def_()'
        fi
      '';
  });
}
