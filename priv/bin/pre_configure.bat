:: #!/bin/sh

:: # Set CONFORM_SCHEMA_PATH, the path to the schema.exs file to use
:: # Use $RELEASE_CONFIG_DIR/$REL_NAME.schema.exs if exists, otherwise releases/VSN/$REL_NAME.schema.exs
:: if [ -z "$CONFORM_SCHEMA_PATH" ]; then
::     if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs" ]; then
::         CONFORM_SCHEMA_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
::     else
::         CONFORM_SCHEMA_PATH="$REL_DIR/$REL_NAME.schema.exs"
::     fi
:: fi
@setlocal EnableDelayedExpansion
@set possible_conform_schema_path=%release_config_dir%\%rel_name%.schema.exs
@if exist %possible_conform_schema_path% (
  @set conform_schema_path=%possible_vmargs%
) else (
  @set conform_schema_path=%rel_dir%\%rel_name%.schema.exs
)

:: # Set CONFORM_CONF_PATH, the path to the .conf file to use
:: # Use $RELEASE_CONFIG_DIR/$REL_NAME.conf if exists, otherwise releases/VSN/$REL_NAME.conf
:: if [ -z "$CONFORM_CONF_PATH" ]; then
::     if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.conf" ]; then
::         CONFORM_CONF_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.conf"
::     else
::         CONFORM_CONF_PATH="$REL_DIR/$REL_NAME.conf"
::     fi
:: fi
@set possible_conform_conf_path=%release_config_dir%\%rel_name%.conf
@if exist %possible_conform_conf_path% (
  @set conform_conf_path=%possible_vmargs%
) else (
  @set conform_conf_path=%rel_dir%\%rel_name%.conf
)

:: __schema_destination="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
@set __schema_destination=%release_config_dir%\%rel_name%.schema.exs
:: __conf_destination="$RELEASE_CONFIG_DIR/$REL_NAME.conf"
@set __conf_destination=%release_config_dir%\%rel_name%.conf
:: __conform_code_path="$RELEASE_ROOT_DIR/lib/*/ebin"
@set __conform_code_path="%release_root_dir%\lib\*\ebin"

@echo CONFORM PRE CONFIFURE
@echo %conform_schema_path%
@echo %conform_conf_path%
@echo %__schema_destination%
@echo %__conf_destination%
@echo %__conform_code_path%

@echo creating sys.config
@setlocal EnableDelayedExpansion
@rem # Convert .conf to sys.config using conform escript
@rem if [ -f "$CONFORM_SCHEMA_PATH" ]; then
@rem     if [ -f "$CONFORM_CONF_PATH" ]; then
@rem         EXTRA_OPTS="$EXTRA_OPTS -conform_schema ${CONFORM_SCHEMA_PATH} -conform_config $CONFORM_CONF_PATH"

@rem         __conform="$REL_DIR/conform"
@rem         # Clobbers input sys.config
@rem         result="$("$BINDIR/escript" "$__conform" --code-path "$__conform_code_path" --conf "$CONFORM_CONF_PATH" --schema "$CONFORM_SCHEMA_PATH" --config "$SYS_CONFIG_PATH" --output-dir "$(dirname $SYS_CONFIG_PATH)")"
@rem         exit_status="$?"
@rem         if [ "$exit_status" -ne 0 ]; then
@rem             exit "$exit_status"
@rem         fi
@rem         if ! grep -q '^%%' "$SYS_CONFIG_PATH" ; then
@rem             tmpfile=$(mktemp "${SYS_CONFIG_PATH}.XXXXXX")
@rem             echo "%%Generated - edit $RELEASE_CONFIG_DIR/$REL_NAME.conf or $RELEASE_CONFIG_DIR/$REL_NAME.conf/sys.config" >> "$tmpfile"
@rem             cat "${SYS_CONFIG_PATH}" >> $tmpfile
@rem             mv "$tmpfile" "${SYS_CONFIG_PATH}"
@rem         fi
@rem     else
@rem         echo "missing .conf, expected it at $CONFORM_CONF_PATH"
@rem         exit 1
@rem     fi
@rem fi
@if exist !conform_schema_path! (
    @setlocal EnableDelayedExpansion
    @if exist !conform_conf_path! (
        @setlocal EnableDelayedExpansion
        @set extra_opts="%extra_opts% -conform_schema !conform_schema_path! -conform_config !conform_conf_path!"
        @set __conform="!rel_dir!\conform"
        :: Clobbers input sys.config
        for %%F in (%sys_config%) do set __output_dir=%%~dpF
        set run_this=!__conform! --code-path !__conform_code_path! --conf "!conform_conf_path!" --schema "!conform_schema_path!" --config "!sys_config!" --output-dir !__output_dir!
        @%escript% !run_this!
        set exit_status=!ERRORLEVEL!
        @echo !exit_status!
        if !exit_status! NEQ 0 (
            exit /B !exit_status!
        )
    ) else (
        @echo missing .conf, expected it at %conform_conf_path%
    )
)
