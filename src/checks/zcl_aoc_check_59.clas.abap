CLASS zcl_aoc_check_59 DEFINITION
  PUBLIC
  INHERITING FROM zcl_aoc_super
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS constructor .

    METHODS check
        REDEFINITION .
    METHODS get_message_text
        REDEFINITION .
  PROTECTED SECTION.

    TYPES:
      BEGIN OF ty_counts,
        level TYPE i,
        paren TYPE i,
        and   TYPE i,
        or    TYPE i,
        not   TYPE i,
      END OF ty_counts .
    TYPES:
      ty_counts_tt TYPE STANDARD TABLE OF ty_counts WITH DEFAULT KEY .

    METHODS walk
      IMPORTING
        !io_node         TYPE REF TO zcl_aoc_boolean_node
        !iv_level        TYPE i DEFAULT 0
      RETURNING
        VALUE(rt_counts) TYPE ty_counts_tt .
    METHODS analyze
      IMPORTING
        !it_tokens     TYPE stokesx_tab
      RETURNING
        VALUE(rv_code) TYPE sci_errc .
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_AOC_CHECK_59 IMPLEMENTATION.


  METHOD analyze.

    DATA: lt_tokens LIKE it_tokens,
          lt_counts TYPE ty_counts_tt,
          ls_count  LIKE LINE OF lt_counts,
          lo_node   TYPE REF TO zcl_aoc_boolean_node.

    FIELD-SYMBOLS: <ls_token> LIKE LINE OF it_tokens.


    READ TABLE it_tokens INDEX 1 ASSIGNING <ls_token>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE <ls_token>-str.
      WHEN 'IF' OR 'ELSEIF' OR 'WHILE'.
* nothing
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    lt_tokens = it_tokens.
    DELETE lt_tokens INDEX 1.

    lo_node = zcl_aoc_boolean=>parse( lt_tokens ).
    IF lo_node IS INITIAL.
      rv_code = '001'.
      RETURN.
    ENDIF.

    IF lo_node->get_type( ) = zcl_aoc_boolean_node=>c_type-paren.
      rv_code = '002'.
      RETURN.
    ENDIF.

    lt_counts = walk( lo_node ).

    LOOP AT lt_counts INTO ls_count.
      IF ls_count-paren > 0 AND ls_count-and >= 0 AND ls_count-or = 0 AND ls_count-not = 0.
        rv_code = '002'.
        RETURN.
      ELSEIF ls_count-paren > 0 AND ls_count-and = 0 AND ls_count-or > 0 AND ls_count-not = 0.
        rv_code = '002'.
        RETURN.
      ELSEIF ls_count-paren = 0 AND ls_count-and > 0 AND ls_count-or > 0 AND ls_count-not = 0.
        rv_code = '003'.
        RETURN.
      ENDIF.
    ENDLOOP.


  ENDMETHOD.


  METHOD check.

* abapOpenChecks
* https://github.com/larshp/abapOpenChecks
* MIT License

    DATA: lt_tokens  LIKE it_tokens,
          lv_code    TYPE sci_errc,
          lv_include TYPE sobj_name.

    FIELD-SYMBOLS: <ls_statement> LIKE LINE OF it_statements,
                   <ls_token>     LIKE LINE OF it_tokens.


    LOOP AT it_statements ASSIGNING <ls_statement>
        WHERE type = scan_stmnt_type-standard.

      CLEAR lt_tokens.

      LOOP AT it_tokens ASSIGNING <ls_token>
          FROM <ls_statement>-from TO <ls_statement>-to.
        APPEND <ls_token> TO lt_tokens.
      ENDLOOP.

      lv_code = analyze( lt_tokens ).

      IF NOT lv_code IS INITIAL.
        lv_include = get_include( p_level = <ls_statement>-level ).
        inform( p_sub_obj_type = c_type_include
                p_sub_obj_name = lv_include
                p_kind         = mv_errty
                p_line         = <ls_token>-row
                p_test         = myname
                p_code         = lv_code ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD constructor.

    super->constructor( ).

    description    = 'Logical expression structure'.        "#EC NOTEXT
    category       = 'ZCL_AOC_CATEGORY'.
    version        = '001'.
    position       = '059'.

    has_attributes = abap_true.
    attributes_ok  = abap_true.

    mv_errty = c_error.

  ENDMETHOD.                    "CONSTRUCTOR


  METHOD get_message_text.

    CLEAR p_text.

    CASE p_code.
      WHEN '001'.
        p_text = 'abapOpenChecks boolean parser error'.     "#EC NOTEXT
      WHEN '002'.
        p_text = 'Superfluous parentheses'.                 "#EC NOTEXT
      WHEN '003'.
        p_text = 'Too few parentheses'.                     "#EC NOTEXT
      WHEN OTHERS.
        super->get_message_text( EXPORTING p_test = p_test
                                           p_code = p_code
                                 IMPORTING p_text = p_text ).
    ENDCASE.

  ENDMETHOD.


  METHOD walk.

    DATA: lo_child    TYPE REF TO zcl_aoc_boolean_node,
          ls_child    TYPE ty_counts,
          lt_children TYPE ty_counts_tt.

    FIELD-SYMBOLS: <ls_count> LIKE LINE OF rt_counts.


    IF io_node->get_type( ) = zcl_aoc_boolean_node=>c_type-compare.
      RETURN.
    ELSEIF io_node->get_type( ) = zcl_aoc_boolean_node=>c_type-paren.
      rt_counts = walk( io_node  = io_node->get_child( )
                        iv_level = iv_level ).
      RETURN.
    ENDIF.

    APPEND INITIAL LINE TO rt_counts ASSIGNING <ls_count>.
    <ls_count>-level = iv_level.

    CASE io_node->get_type( ).
      WHEN zcl_aoc_boolean_node=>c_type-and.
        <ls_count>-and = 1.
      WHEN zcl_aoc_boolean_node=>c_type-or.
        <ls_count>-or = 1.
      WHEN zcl_aoc_boolean_node=>c_type-not.
        <ls_count>-not = 1.
      WHEN OTHERS.
        ASSERT 0 = 1.
    ENDCASE.

    LOOP AT io_node->get_children( ) INTO lo_child.
      IF lo_child->get_type( ) = zcl_aoc_boolean_node=>c_type-paren.
        <ls_count>-paren = <ls_count>-paren + 1.
      ENDIF.

      lt_children = walk( io_node  = lo_child
                          iv_level = iv_level + 1 ).
      APPEND LINES OF lt_children TO rt_counts.

      LOOP AT lt_children INTO ls_child WHERE level = iv_level + 1.
        <ls_count>-paren = <ls_count>-paren + ls_child-paren.
        <ls_count>-and   = <ls_count>-and   + ls_child-and.
        <ls_count>-or    = <ls_count>-or    + ls_child-or.
        <ls_count>-not   = <ls_count>-not   + ls_child-not.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.