// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// Guardian BBS Software	     Copyright 2013-2017 Vincent Chapman
// Vertigo BBS Software		     Copyright 2017 Andrew Pamment
// ====================================================================
//
// This file is part of Vertigo BBS.
//
// Vertigo BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Vertigo BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Vertigo BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

Program MIDE;

{$I M_OPS.PAS}

Uses
  {$IFDEF DEBUG}
    LineInfo,
    HeapTrc,
  {$ENDIF}
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  DOS,
  m_Types,
  m_Input,
  m_Output,
  m_MenuBox,
  m_MenuForm,
  m_MenuInput,
  m_QuickSort,
  m_Strings,
  m_FileIO,
  m_IniReader,
  MPL_Compile;

Const
  mideVersion      = '2.0.0';
  mideMaxFileLines = 10000;
  mideMaxOpenFiles = 10;
  mideMaxLineSize  = 254;
  mideTopY         : Byte = 1;
  mideBotY         : Byte = 24;
  mideWinSize      : Byte = 24;
  mideExecOpts     : String[100] = '';

  colEditBorder  = 25;  { 31 }
  colEditHeader  = 31;  { 31 }
  colEditStatus  = 9 + 1 * 16;
  colEditPosBar  = 9 + 1 * 16;

Const
  Keywords = 24;
  Keyword : Array[1..Keywords] of String[9] = (
    ( 'AND'       ),
    ( 'BEGIN'     ),
    ( 'CASE'      ),
    ( 'CONST'     ),
    ( 'DO'        ),
    ( 'DOWNTO'    ),
    ( 'ELSE'      ),
    ( 'END'       ),
    ( 'FOR'       ),
    ( 'FUNCTION'  ),
    ( 'IF'        ),
    ( 'INCLUDE'   ),
    ( 'NOT'       ),
    ( 'OF'        ),
    ( 'OR'        ),
    ( 'PROCEDURE' ),
    ( 'REPEAT'    ),
    ( 'THEN'      ),
    ( 'TO'        ),
    ( 'TYPE'      ),
    ( 'UNTIL'     ),
    ( 'USES'      ),
    ( 'VAR'       ),
    ( 'WHILE'     )
  );

Var
  cfg_TabSpaces   : Byte;
  cfg_Screen50    : Boolean;
  cfg_AutoIndent  : Boolean;
  cfg_Highlight   : Boolean;
  cfg_ExecPath    : String[160];
  cfg_ExecUser    : String[35];
  cfg_ExecPW      : String[20];
//  cfg_TextString  : Byte;
  cfg_TextKeyword : Byte;
  cfg_TextComment : Byte;
  cfg_TextNormal  : Byte;
  cfg_TextNumber  : Byte;
  cfg_TextHex     : Byte;
  cfg_TextCharStr : Byte;

Type
  PEditorWindow = ^TEditorWindow;
  TEditorWindow = Object
    Path       : String;
    FileName   : String;
    Changed    : Boolean;
    TotalLines : Word;
    CurLine    : Word;
    CurX       : Integer;
    CurY       : Integer;
    ScrlX      : Integer;
    ScrlY      : Integer;
    BarPos     : Byte;
    BarPosLast : Byte;
    TopPage    : Integer;
    TextData   : Array[1..mideMaxFileLines] of ^String;
    Box        : TMenuBox;

    Constructor Init;
    Destructor  Done;
    Function    Load : Boolean;
    Procedure   ReDrawFull;
  End;

Const
  MaxCutText = 200;

Type
  CutTextPtr = ^CutTextRec;
  CutTextRec = String[255];

Var
  CutPasted   : Boolean = False;
  CutTextPos  : Word    = 0;
  CutText     : Array[1..MaxCutText] of CutTextPTR;
  Console     : TOutput;
  Input       : TInput;
  StartDir    : String;
  CurWinNum   : Byte;
  TotalWinNum : Byte;
  CurWin      : Array[1..mideMaxOpenFiles] of PEditorWindow;

Procedure DisposeText;
Var
  Count : LongInt;
Begin
  For Count := CurWin[CurWinNum]^.TotalLines DownTo 1 Do
    Dispose (CurWin[CurWinNum]^.TextData[Count]);

  CurWin[CurWinNum]^.TotalLines := 0;
End;

Function ShowMsgBox (BoxType: Byte; Str: String) : Boolean;
Var
  Len    : Byte;
  Len2   : Byte;
  Pos    : Byte;
  InKey  : TInput;
  MsgBox : TMenuBox;
Begin
  ShowMsgBox := True;

{ 0 = ok box }
{ 1 = y/n box }
{ 2 = just box }
{ 3 = just box dont close }

  MsgBox := TMenuBox.Create(Console);
  InKey  := TInput.Create;

  Len := (80 - (Length(Str) + 2)) DIV 2;
  Pos := 1;

  MsgBox.FrameType := 6;
  MsgBox.Header    := ' Info ';
  MsgBox.Box3D     := True;

  If BoxType < 2 Then
    MsgBox.Open (Len, 10, Len + Length(Str) + 3, 15)
  Else
    MsgBox.Open (Len, 10, Len + Length(Str) + 3, 14);

  Console.WriteXY (Len + 2, 12, 0 + 7 * 16, Str);

  Case BoxType of
    0 : Begin
          Len2 := (Length(Str) - 4) DIV 2;
          Console.WriteXY (Len + Len2 + 2, 14, 31, ' OK ');
          InKey.ReadKey;
        End;
    1 : Repeat
          Len2 := (Length(Str) - 9) DIV 2;
          Console.WriteXY (Len + Len2 + 2, 14, 1 + 7 * 16, ' YES ');
          Console.WriteXY (Len + Len2 + 7, 14, 1 + 7 * 16, ' NO ');
          If Pos = 1 Then
            Console.WriteXY (Len + Len2 + 2, 14, 31, ' YES ')
          Else
            Console.WriteXY (Len + Len2 + 7, 14, 31, ' NO ');

          Case UpCase(InKey.ReadKey) of
            #00 : Case InKey.ReadKey of
                    #75 : Pos := 1;
                    #77 : Pos := 0;
                  End;
            #13 : Begin
                    ShowMsgBox := Boolean(Pos);
                    Break;
                  End;
            #32 : If Pos = 0 Then Inc(Pos) Else Pos := 0;
            'N' : Begin
                    ShowMsgBox := False;
                    Break;
                  End;
            'Y' : Begin
                    ShowMsgBox := True;
                    Break;
                  End;
          End;
        Until False;
  End;

  If BoxType <> 3 Then Begin
    MsgBox.Close;
    MsgBox.Free;
  End;

  InKey.Free;
End;

Constructor TEditorWindow.Init;
Begin
  BarPos     := 3;
  BarPosLast := 0;
  Changed    := False;
  CurLine    := 1;
  TotalLines := 1;
  CurX       := 1;
  CurY       := 1;
  ScrlX      := 0;
  ScrlY      := 1;
  TopPage    := 1;
End;

Destructor TEditorWindow.Done;
Begin
End;

Function TEditorWindow.Load : Boolean;
Var
  TF  : Text;
  Str : String;
Begin
  Result := False;

  Assign (TF, FileName);
  Reset  (TF);

  If IoResult <> 0 Then Exit;

  TotalLines := 0;

  While Not Eof(TF) Do Begin

    ReadLn (TF, Str);

    While Pos (#9, Str) > 0 Do Begin
      Insert (strRep(' ', cfg_TabSpaces), Str, Pos(#9, Str));
      Delete (Str, Pos(#9, Str), 1);
    End;

    Str := strStripR(Str, ' ');

    If Length(Str) > mideMaxLineSize Then Begin
      ShowMsgBox (0, 'Line length cannot be more than ' + strI2S(mideMaxLineSize) + ' chars');
      DisposeText;
      Close(TF);
      Exit;
    End;

    Inc (TotalLines);

    New (TextData[TotalLines]);
    TextData[TotalLines]^ := Str;

    If TotalLines = mideMaxFileLines Then Begin
      ShowMsgBox (0, 'File cannot be more than ' + strI2S(mideMaxFileLines) + ' lines');
      DisposeText;
      Close(TF);
      Exit;
    End;
  End;

  Close (TF);

  If TotalLines = 0 Then Begin
    Inc(TotalLines);
    New(TextData[TotalLines]);
    TextData[TotalLines]^ := '';
  End;

  Load := True;
End;

Procedure DrawLineHighlight (Y: Byte; S: String);
Const
  chNumber = ['0'..'9','.'];
  chIdent  = ['a'..'z','A'..'Z','_'];
  chIdent2 = ['a'..'z','A'..'Z','_','0'..'9'];
  chOpChar = ['+', '-', '/', '*', ':', '='];
  chHexNum = ['a'..'f', 'A'..'F', '0'..'9'];
  chOther  = ['(', ')', ',', '.', '[', ']'];

Type
  Tokens = (
    tSTRING,
    tCOMMENT,
    tTEXT,
    tNUMBER,
    tKEYWORD,
    tOPCHAR,
    tCHARNUM,
    tHEXNUM,
    tEOL
  );

Var
  ResStr    : String = '';
  StrPos    : Byte = 0;
  ScrollPos : Byte = 1;
  Done      : Boolean = False;

  Function GetChar : Char;
  Begin
    Result := #00;

    While StrPos < Length(S) Do Begin
      Inc (StrPos);

      Result := S[StrPos];
      ResStr := ResStr + Result;

      Break;
    End;
  End;

  Function NextToken : Tokens;
  Var
    Ch    : Char;
    Key   : String;
    Count : Byte;
  Begin
    Result := tEOL;
    ResStr := '';
    Key    := '';

    Repeat
      Ch := GetChar;

      If Ch = #00 Then Break;

      If Ch <> #32 Then Key := Key + Ch;

      If Ch in chIdent Then Begin
        Result := tTEXT;

        While Ch in chIdent2 Do Begin
          Ch  := GetChar;

          If Ch = #00 Then Break;

          Key := Key + Ch;
        End;

        If Ch <> #00 Then Begin
          Dec(StrPos);
          Dec(Key[0]);
          Dec(ResStr[0]);
        End;

        For Count := 1 to Keywords Do
          If Keyword[Count] = strUpper(Key) Then Begin
            Result := tKEYWORD;
            Exit;
          End;

        Exit;
      End Else
      If Ch = '''' Then Begin
        Result := tSTRING;

        Repeat
          Ch := GetChar;

          Case Ch of
            #00  : Exit;
            '''' : If S[StrPos + 1] = '''' Then GetChar Else Exit;
          End;
        Until False;
      End Else
      If (Ch = '/') and (S[StrPos + 1] = '/') Then Begin
        Result := tCOMMENT;

        Repeat Until GetChar = #00;

        Exit;
      End Else
      If Ch in chNumber Then Begin
        Result := tNUMBER;

        While Ch in chNumber Do Begin
          Ch := GetChar;

          If Ch = #00 Then Exit;
        End;

        Dec(StrPos);
        Dec(ResStr[0]);

        Exit;
      End Else
      If Ch in chOpChar Then Begin
        Result := tOPCHAR;

        While Ch in chOpChar Do Begin
          Ch  := GetChar;

          If Ch = #00 Then Break;

          Key := Key + Ch;
        End;

        If Ch <> #00 Then Begin
          Dec(StrPos);
          Dec(Key[0]);
          Dec(ResStr[0]);
        End;

        Exit;
      End Else
      If Ch = '#' Then Begin
        Result := tCHARNUM;

        Repeat
          Ch := GetChar;

          If Ch = #00 Then Exit;
        Until Not (Ch in chNumber);

        Dec(StrPos);
        Dec(ResStr[0]);

        Exit;
      End Else
      If Ch = '$' Then Begin
        Result := tHEXNUM;

        Repeat
          Ch := GetChar;

          If Ch = #00 Then Exit;
        Until Not (Ch in chNumber);

        Dec(StrPos);
        Dec(ResStr[0]);

        Exit;
      End Else Begin
        Result := tTEXT;
        Exit;
      End;
    Until False;
  End;

  Procedure WritePart (Str: String);
  Var
    A : Byte;
  Begin
    For A := 1 to Length(Str) Do Begin
      If ScrollPos < CurWin[CurWinNum]^.ScrlX + 1 Then
        Inc (ScrollPos)
      Else
        If Console.CursorX < 79 Then Console.WriteChar (Str[A]);
    End;
  End;

Begin
  Console.CursorXY(2, Y);

  Repeat
    Case NextToken of
      tEOL     : Break;
      tNUMBER  : Console.TextAttr := cfg_TextNumber;
      tCOMMENT : Console.TextAttr := cfg_TextComment;
      tKEYWORD : Console.TextAttr := cfg_TextKeyword;
      tOPCHAR  : Console.TextAttr := cfg_TextKeyword;
      tSTRING,
      tCHARNUM : Console.TextAttr := cfg_TextCharStr;
      tHEXNUM  : Console.TextAttr := cfg_TextHex;
    Else
      Console.TextAttr := cfg_TextNormal;
    End;

    WritePart(ResStr);
  Until Done;

  Console.ClearEOL;
  Console.WriteXY (80, Y, colEditStatus, '�');
End;

Procedure DrawLine (Y: Byte; S: String);
Begin
  If cfg_Highlight Then
    DrawLineHighlight (Y, S)
  Else
    Console.WriteXY (2, Y, cfg_TextNormal, strPadR(Copy(S, CurWin[CurWinNum]^.ScrlX + 1, 255), 77, ' '));
End;

Procedure DrawPage;
Var
  A : Byte;
  S : String;
Begin
  For A := 0 to mideWinSize - 3 Do Begin
    If CurWin[CurWinNum]^.TopPage + A <= CurWin[CurWinNum]^.TotalLines Then
      S := CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.TopPage + A]^
    Else
      S := '';

    DrawLine (2 + A, S);
  End;
End;

Procedure TEditorWindow.ReDrawFull;
Var
  A : Byte;
Begin
  Box.FrameType := 2;
  Box.Box3D     := False;
  Box.BoxAttr   := colEditBorder;
  Box.HeadAttr  := colEditHeader;
  Box.Shadow    := False;
  Box.Header    := ' ' + FileName + ' [' + strI2S(CurWinNum) + '] ';

  Box.Open (1, mideTopY, 80, mideBotY);

  For A := mideTopY + 1 to mideBotY - 1 Do
    Console.WriteXY (80, A, colEditStatus, '�');

  DrawPage;
End;

Procedure UpdateFileInfo (Num: Word; Str: String);
Var
  F    : File;
  DT   : DateTime;
  Time : LongInt;
Begin
  If Str = '' Then
    Console.WriteXY (8, 19, 120, strRep(' ', 31))
  Else Begin
    Assign (F, Str);

    Str  := '';
    Time := 0;

    Reset  (F, 1);

    If IoResult = 0 Then Begin
      GetFTime   (F, Time);
      UnpackTime (Time, DT);

      Time := FileSize(F);

      Close (F);
    End;

    Str := strZero(DT.Month) + '/' + strZero(DT.Day) + '/' + strI2S(DT.Year) + ' ' + strZero(DT.Hour) + ':' + strZero(DT.Min);

    Console.WriteXY (8, 19, 120, strPadL(strComma(Time) + ' ' + Str, 31, ' '));
  End;
End;

Function OpenDialog (Mask: String; Var Path, FN: String) : Boolean;
Const
  ColorBox = 31;
  ColorBar = 7 + 0 * 16;
Var
  DirList  : TMenuList;
  FileList : TMenuList;
  InStr    : TMenuInput;
  Str      : String;

  Procedure UpdateInfo;
  Begin
    Console.WriteXY (8,  7, 31, strPadR(Path, 40, ' '));
    Console.WriteXY (8, 21, 31, strPadR(Mask, 40, ' '));
  End;

  Procedure CreateLists;
  Var
    Dir      : SearchRec;
    DirSort  : TQuickSort;
    FileSort : TQuickSort;
    Count    : LongInt;
  Begin
    DirList.Clear;
    FileList.Clear;

    While Path[Length(Path)] = PathSep Do Dec(Path[0]);
    ChDir(Path);
    Path := Path + PathSep;

    If IoResult <> 0 Then Exit;

    DirList.Picked  := 1;
    FileList.Picked := 1;

    UpdateInfo;

    DirSort  := TQuickSort.Create;
    FileSort := TQuickSort.Create;

    FindFirst (Path + '*', AnyFile - VolumeID, Dir);
    While DosError = 0 Do Begin
      If (Dir.Attr And Directory = 0) or ((Dir.Attr And Directory <> 0) And (Dir.Name = '.')) Then Begin
        FindNext(Dir);
        Continue;
      End;
      DirSort.Add (Dir.Name, 0);
      FindNext (Dir);
    End;
    FindClose(Dir);

    FindFirst (Path + Mask, AnyFile - VolumeID, Dir);
    While DosError = 0 Do Begin
      If Dir.Attr And Directory <> 0 Then Begin
        FindNext(Dir);
        Continue;
      End;

      FileSort.Add(Dir.Name, 0);
      FindNext(Dir);
    End;
    FindClose(Dir);

    DirSort.Sort  (1, DirSort.Total,  qAscending);
    FileSort.Sort (1, FileSort.Total, qAscending);

    For Count := 1 to DirSort.Total Do
      DirList.Add(DirSort.Data[Count]^.Name, 0);

    For Count := 1 to FileSort.Total Do
      FileList.Add(FileSort.Data[Count]^.Name, 0);

    DirSort.Free;
    FileSort.Free;

    Console.WriteXY (14, 9, 113, strPadR('(' + strComma(FileList.ListMax) + ')', 7, ' '));
    Console.WriteXY (53, 9, 113, strPadR('(' + strComma(DirList.ListMax) + ')', 7, ' '));
  End;

Var
  Box  : TMenuBox;
  Done : Boolean;
  Mode : Byte;
Begin
  Result   := False;
  Box      := TMenuBox.Create(Console);
  DirList  := TMenuList.Create(Console);
  FileList := TMenuList.Create(Console);

  FileList.NoWindow   := True;
  FileList.LoChars    := #9#13#27;
  FileList.HiChars    := #77;
  FileList.HiAttr     := ColorBar;
  FileList.LoAttr     := ColorBox;

  DirList.NoWindow    := True;
  DirList.NoInput     := True;
  DirList.HiAttr      := ColorBox;
  DirList.LoAttr      := ColorBox;

  Box.Header := ' Open a file ';

  Box.Open (6, 5, 74, 22);

  Console.WriteXY ( 8,  6, 113, 'Directory');
  Console.WriteXY ( 8,  9, 113, 'Files');
  Console.WriteXY (41,  9, 113, 'Directories');
  Console.WriteXY ( 8, 20, 113, 'File Mask');
  Console.WriteXY ( 8, 21,  31, strRep(' ', 40));

  FileList.SetStatusProc(@UpdateFileInfo);

  CreateLists;

  DirList.Open (40, 9, 72, 19);
  DirList.Update;

  Done := False;

  Repeat
    FileList.Open (7, 9, 39, 19);

    Case FileList.ExitCode of
      #09,
      #77 : Begin
              FileList.HiAttr := ColorBox;
              DirList.NoInput := False;
              DirList.LoChars := #09#13#27;
              DirList.HiChars := #75;
              DirList.HiAttr  := ColorBar;

              FileList.Update;

              Repeat
                DirList.Open(40, 9, 72, 19);

                Case DirList.ExitCode of
                  #09 : Begin
                          DirList.HiAttr := ColorBox;
                          DirList.Update;

                          Mode  := 1;
                          InStr := TMenuInput.Create(Console);
                          InStr.LoChars := #09#13#27;

                          Repeat
                            Case Mode of
                              1 : Begin
                                    Str := InStr.GetStr(8, 21, 40, 255, 1, Mask);

                                    Case InStr.ExitCode of
                                      #09 : Mode := 2;
                                      #13 : Begin
                                              Mask := Str;
                                              CreateLists;
                                              FileList.Update;
                                              DirList.Update;
                                            End;
                                      #27 : Begin
                                              Done := True;
                                              Break;
                                            End;
                                    End;
                                  End;
                              2 : Begin
                                    UpdateInfo;

                                    Str := InStr.GetStr(8, 7, 40, 255, 1, Path);

                                    Case InStr.ExitCode of
                                      #09 : Break;
                                      #13 : Begin
                                              ChDir(Str);

                                              If IoResult = 0 Then Begin
                                                Path := Str;
                                                CreateLists;
                                                FileList.Update;
                                                DirList.Update;
                                              End;
                                            End;
                                      #27 : Begin
                                              Done := True;
                                              Break;
                                            End;
                                    End;
                                  End;
                            End;
                          Until False;

                          InStr.Free;

                          UpdateInfo;

                          Break;
                        End;
                  #13 : If DirList.ListMax > 0 Then Begin
                          ChDir  (DirList.List[DirList.Picked]^.Name);
                          GetDir (0, Path);

                          Path := Path + PathSep;

                          CreateLists;
                          FileList.Update;
                        End;
                  #27 : Done := True;
                  #75 : Break;
                End;
              Until Done;

              DirList.NoInput := True;
              DirList.HiAttr  := ColorBox;
              FileList.HiAttr := ColorBar;
              DirList.Update;
            End;
      #13 : If FileList.ListMax > 0 Then Begin
              FN     := FileList.List[FileList.Picked]^.Name;
              Result := True;
              Break;
            End;
      #27 : Break;
    End;
  Until Done;

  Box.Close;
  Box.Free;
  FileList.Free;
  DirList.Free;
End;

Procedure DrawStatus;
Begin
  Console.WriteXY (1, mideBotY + 1, 112, ' MIDE v' + mideVersion + ' �' + strRep(' ', 55) + '� ESC/Menu ');
End;

Procedure FillScreen;
Var
  Count : Byte;
Begin
  For Count := 1 to mideBotY Do
    Console.WriteXY (1, Count, 8, strRep('�', 80));

  DrawStatus;
End;

Procedure LoadAndOpen (FN: String);
Begin
  TotalWinNum := TotalWinNum + 1;
  CurWinNum   := TotalWinNum;

  New (CurWin[CurWinNum], Init);

  CurWin[CurWinNum]^.Box      := TMenuBox.Create(Console);
  CurWin[CurWinNum]^.FileName := FN;

  If Not CurWin[CurWinNum]^.Load Then Begin
    CurWin[CurWinNum]^.Box.Free;
    Dispose (CurWin[CurWinNum], Done);

    CurWin[CurWinNum] := NIL;

    Dec (TotalWinNum);
    CurWinNum := TotalWinNum;
  End;
End;

Procedure ReDrawScreen;
Begin
  If CurWinNum > 0 Then
    CurWin[CurWinNum]^.ReDrawFull
  Else
    FillScreen;
End;

Function InBox (Header, Text, Def: String; Len, MaxLen: Byte) : String;
Var
  Box     : TMenuBox;
  Input   : TMenuInput;
  Offset  : Byte;
  Str     : String;
  WinSize : Byte;
Begin
  If Len > Length(Text) Then
    Offset := Len
  Else
    Offset := Length(Text);

  WinSize := (80 - Offset + 2) DIV 2;

  Box   := TMenuBox.Create(Console);
  Input := TMenuInput.Create(Console);

  Box.Header    := ' ' + Header + ' ';
  Input.LoChars := #13#27;

  Box.Open (WinSize, 10, WinSize + Offset + 3, 15);

  Console.WriteXY (WinSize + 2, 12, 112, Text);

  Str := Input.GetStr(WinSize + 2, 13, Len, MaxLen, 1, Def);

  Box.Close;

  If Input.ExitCode = #27 Then Str := '';

  Input.Free;
  Box.Free;

  Result := Str;
End;

Function SaveFile (FNum: Byte; Check, AskReName: Boolean) : Boolean;
Var
  S  : String;
  OK : Boolean;
  TF : Text;
  A  : LongInt;
Begin
  Result := False;

  If CurWin[FNum] = NIL Then Exit;

  If Check And Not CurWin[FNum]^.Changed Then Begin
    Result := True;
    Exit;
  End;

  OK := True;

  If Check And CurWin[FNum]^.Changed Then
    If Not ShowMsgBox(1, CurWin[FNum]^.FileName + ' has been changed.  Save file?') Then
      Exit;

  If AskReName Then
    S := InBox('File', 'File Name:', CurWin[FNum]^.FileName, 50, 255)
  Else
    S := CurWin[FNum]^.FileName;

  If S = '' Then Begin
    ReDrawScreen;
    Exit;
  End;

  If S <> CurWin[FNum]^.FileName Then
    If FileExist(StartDir + S) Then
      OK := ShowMsgBox(1, S + ' already exists.  Overwrite?');

  If OK Then Begin
    CurWin[FNum]^.Changed  := False;
    CurWin[FNum]^.FileName := S;

    Assign (TF, S);
    ReWrite (TF);
    For A := 1 to CurWin[FNum]^.TotalLines Do Begin
      S := CurWin[FNum]^.TextData[A]^;
      WriteLn (TF, S);
    End;
    Close (TF);

    Result := True;
  End;

  ReDrawScreen;
End;

Procedure RelocatePos (X: Byte; Line: Word);
Begin
  With CurWin[CurWinNum]^ Do Begin
    TopPage := Line;
    CurLine := Line;
    CurY    := 1;
    CurX    := X;
    If CurX > 77 Then ScrlX := CurX - 77 Else ScrlX := 0;
    If ScrlX > 0 Then CurX := 77;
  End;
End;

Procedure CompileStatusUpdate (Info: TParserUpdateInfo);
Var
  Percent : Byte;
Begin
  Case Info.Mode of
    StatusUpdate : Begin
                     Console.WriteXY (25, 9, 112, strPadR(Info.FileName, 45, ' '));
                     Percent := Round(Info.FilePosition / Info.FileSize * 100 / 5);
                     If Percent > 100 Then Percent := 100;
                     Console.WriteXY (25, 10, 112, strRep(#178, Percent) + strRep(#176, 20 - Percent) + strPadL(strI2S(Percent * 5) + '%', 5, ' '));
                   End;
    StatusDone   : Begin
                     If Info.ErrorType = 0 Then
                       Console.WriteXY (11, 13,  31, strPadC('Compile successful: Press any key.', 59, ' '))
                     Else Begin
                       Console.WriteXY (25, 10, 112, strPadR('Error (line ' + strI2S(Info.ErrorLine) + ', col ' + strI2S(Info.ErrorCol) + ')', 40, ' '));
                       Console.WriteXY (25, 11, 112, Info.ErrorText);
                       Console.WriteXY (11, 13,  31, strPadC('Compile error: Press any key.', 59, ' '));

                       RelocatePos(Info.ErrorCol, Info.ErrorLine);
                     End;

                     Repeat Until Input.ReadKey <> #0;
                   End;
  End;
End;

Function Compile : Boolean;
Var
  Box     : TMenuBox;
  Compile : TParserEngine;
Begin
  Result := False;

  If CurWinNum = 0 Then Exit;

  If Not SaveFile(CurWinNum, True, False) Then Exit;

  Box := TMenuBox.Create(Console);

  Box.Open (10, 7, 70, 14);

  Console.WriteXY (19,  9, 112, 'File: ' {+ JustFile(CurWin[CurWinNum]^.FileName)});
  Console.WriteXY (17, 10, 112, 'Status:');
  Console.WriteXY (16, 11, 112, 'Message: Ok');
  Console.WriteXY (11, 13,  31, strPadC('Working...', 59, ' '));

  Compile := TParserEngine.Create(CompileStatusUpdate);
  Result  := Compile.Compile(CurWin[CurWinNum]^.FileName);

  Compile.Free;
  Box.Close;
  Box.Free;

  CurWin[CurWinNum]^.ReDrawFull;
End;

Procedure RunProgram;
Var
  Image  : TConsoleImageRec;
  CmdStr : String;
Begin
  If Not Compile Then Exit;

  Console.GetScreenImage(1, 1, 80, Console.ScreenSize, Image);

  mideExecOpts := InBox('Execute', 'Enter optional data or blank for none:', mideExecOpts, 50, 100);

  CmdStr := cfg_ExecPath + 'vertigo' + ' -u' + cfg_ExecUser + ' -p' + cfg_ExecPW + ' -x' + JustFileName(CurWin[CurWinNum]^.FileName);

  If mideExecOpts <> '' Then
    CmdStr := CmdStr + '_' + strReplace(mideExecOpts, ' ', '_');

  // save directory?

  {$IFDEF UNIX}
    fpSystem (CmdStr);
  {$ELSE}
    Exec (GetEnv('COMSPEC'), '/C' + CmdStr);
  {$ENDIF}

  // restore directory?

  Console.PutScreenImage(Image);
End;

Procedure CloseFile;
Var
  A : Byte;
Begin
  If CurWin[CurWinNum] = NIL Then Exit;

  SaveFile(CurWinNum, True, True);

  DisposeText;

  If CurWinNum = TotalWinNum Then Begin
    CurWin[CurWinNum]^.Box.Free;
    Dispose (CurWin[CurWinNum], Done);

    CurWin[CurWinNum] := NIL;

    Dec (CurWinNum);
    Dec (TotalWinNum);
  End Else Begin
    CurWin[CurWinNum]^.Box.Free;
    Dispose (CurWin[CurWinNum], Done);
//    CurWin[CurWinNum] := NIL; do we need this!!??
    For A := CurWinNum to TotalWinNum - 1 Do
      CurWin[A] := CurWin[A + 1];

    Dec (TotalWinNum);
  End;

  If CurWinNum > TotalWinNum Then CurWinNum := TotalWinNum;

  ReDrawScreen;
End;

Procedure ScrollUp;
Begin
  If CurWin[CurWinNum]^.TopPage = 1 Then Exit;

  Dec (CurWin[CurWinNum]^.TopPage);

  DrawPage;
End;

Procedure ScrollDown;
Begin
  If CurWin[CurWinNum]^.TopPage + (mideWinSize - 4) = CurWin[CurWinNum]^.TotalLines Then Exit;

  Inc (CurWin[CurWinNum]^.TopPage);

  DrawPage;
End;

Procedure Relocate (ReDraw: Boolean);
Begin
  With CurWin[CurWinNum]^ Do Begin
    If CurX + ScrlX > Length(TextData[CurLine]^) Then Begin
      CurX := Length(TextData[CurLine]^) + 1;

      If ScrlX > 0 Then Begin
        If CurX > 77 Then ScrlX := CurX - 77 Else ScrlX := 0;
        If ScrlX > 0 Then CurX := 77;
        DrawPage;
      End Else
        If ReDraw Then DrawPage;
    End Else
      If ReDraw Then DrawPage;
  End;
End;

Procedure DeleteLine (Update: Boolean);
Var
  A : Integer;
  S : String;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    For A := CurLine to TotalLines-1 Do Begin
      S := TextData[A+1]^;
      TextData[A]^ := S;
    End;

    If ((CurLine = 1) and (TotalLines = 1)) or (CurLine = TotalLines) Then Begin
      S := '';
      TextData[CurLine]^ := S;
    End Else Begin
      Dispose(TextData[TotalLines]);
      Dec (TotalLines);
    End;

    If Update Then Begin
      If CurX > Length(TextData[CurLine]^) + 1 Then CurX := Length(TextData[CurLine]^) + 1;
      DrawPage;
    End;

    Changed := True;
  End;
End;

Procedure InsertLine (Num : Integer);
Var
  A : Integer;
  S : String;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If TotalLines = mideMaxFileLines Then Exit;

    Inc (TotalLines);
    New(TextData[TotalLines]);

    For A := TotalLines DownTo Num + 1 Do Begin
      S := TextData[A-1]^;
      TextData[A]^ := S;
    End;

    S := '';
    TextData[Num]^ := S;
    Changed := True;
  End;
End;

Procedure AddChar (Ch : Char);
Var
  S : String;
Begin
  If CurWinNum = 0 Then Exit;

  If Length(CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^) = mideMaxLineSize Then Exit;

  S := CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^;
  Insert (Ch, S, CurWin[CurWinNum]^.CurX + CurWin[CurWinNum]^.ScrlX);
  CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^ := S;

  If CurWin[CurWinNum]^.CurX = 78 Then Begin
    Inc (CurWin[CurWinNum]^.ScrlX);
    DrawPage;
  End Else Begin
    DrawLine (CurWin[CurWinNum]^.CurY + 1, S);
    Inc (CurWin[CurWinNum]^.CurX);
  End;

  CurWin[CurWinNum]^.Changed := True;
End;

Procedure DeleteChar;
Var
  S  : String;
  S2 : String;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    Changed := True;

    If CurX > Length(TextData[CurLine]^) Then Begin
      If TextData[CurLine]^ = '' Then
        DeleteLine(True)
      Else
      If CurLine < TotalLines Then Begin
        S  := TextData[CurLine]^;
        S2 := TextData[CurLine + 1]^;

        If Length(S) + Length(S2) <= mideMaxLineSize Then Begin
          S := S + S2;
          DeleteLine(False);
          TextData[CurLine]^ := S;
          DrawPage;
        End;
      End;

      Exit;
    End;

    S := TextData[CurLine]^;
    Delete (S, CurX + ScrlX, 1);
    TextData[CurLine]^ := S;
    DrawLine (CurY + 1, S);
  End;
End;

Procedure RightArrow;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If CurX + ScrlX = Length(TextData[CurLine]^) + 1 Then Exit;

    If CurX = 78 Then Begin
      If ScrlX < mideMaxLineSize - 77 Then Begin
        Inc (ScrlX);
        DrawPage;
      End;
    End Else
      Inc (CurX);
  End;
End;

Procedure DownArrow;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If CurLine = TotalLines Then Exit;
    Inc (CurLine);

    If CurY < (mideWinSize - 2) Then
      Inc (CurY)
    Else
      ScrollDown;

    Relocate(False);
  End;
End;

Procedure UpArrow;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If CurLine = 1 Then Exit;
    Dec (CurLine);
    If CurY > 1 Then
      Dec (CurY)
    Else
      ScrollUp;

    Relocate(False);
  End;
End;

Procedure BackSpace;
Var
  S  : String;
  S2 : String;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    Changed := True;

    If (CurLine > 1) and (Length(TextData[CurLine]^) = 0) Then Begin
      DeleteLine(True);
      CurX := 256;
      UpArrow;
      Exit;
    End Else
    If (CurLine > 1) and (CurX = 1) and (ScrlX = 0) Then Begin
      S  := TextData[CurLine-1]^;
      S2 := TextData[CurLine]^;

      If Length(S) + Length(S2) > mideMaxLineSize Then Begin
        CurX := mideMaxLineSize + 1;
        UpArrow;
        Exit;
      End;

      CurX := Length(S) + 1;
      S    := S + strStripR(S2, ' ');

      TextData[CurLine-1]^ := S;

      DeleteLine(False);
      UpArrow;

      If CurX > 77 Then ScrlX := CurX - 77 Else ScrlX := 0;
      If ScrlX > 0 Then CurX := 77;

      DrawPage;
      Exit;
    End;

    If CurX > 1 Then Begin
      S := TextData[CurLine]^;
      Delete (S, CurX + ScrlX - 1, 1);
      TextData[CurLine]^ := S;
      Dec (CurX);
      DrawLine (CurY + 1, S);
    End Else
    If ScrlX > 0 Then Begin
      S := TextData[CurLine]^;
      Delete (S, CurX + ScrlX - 1, 1);
      TextData[CurLine]^ := S;
      Dec (ScrlX);
      DrawPage;
    End;
  End;
End;

Procedure PageUp;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If CurLine > (mideWinSize - 4) Then Begin
      Dec (TopPage, (mideWinSize - 4));
      Dec (CurLine, (mideWinSize - 4));

      If TopPage < 1 Then Begin
        TopPage := 1;
        CurY    := CurLine - TopPage + 1;
      End;

      Relocate(True);
    End Else
    If TopPage > 1 Then Begin
      CurLine := 1;
      CurY    := 1;
      TopPage := 1;

      Relocate(True);
    End Else Begin
      CurY    := 1;
      CurLine := 1;
    End;
  End;
End;

Procedure PageDown;
Begin
  If CurWinNum = 0 Then Exit;

  With CurWin[CurWinNum]^ Do Begin
    If CurLine + (mideWinSize - 4) <= TotalLines Then Begin
      Inc (TopPage, (mideWinSize - 4));
      Inc (CurLine, (mideWinSize - 4));

      Relocate(True);
    End Else If TopPage <> TotalLines - CurY + 1 Then Begin
      TopPage := TotalLines - CurY + 1;
      CurLine := TotalLines;

      Relocate(True);
    End;
  End;
End;

Procedure InsertTab;
Var
  A : Byte;
Begin
  If CurWinNum = 0 Then Exit;

  For A := 1 to cfg_TabSpaces Do
    AddChar(' ');
End;

Procedure Enter;
Var
  S1     : String;
  S2     : String;
  Indent : Byte;
Begin
  If CurWinNum = 0 Then Exit;

  Indent := 1;

  With CurWin[CurWinNum]^ Do Begin
    InsertLine (CurLine + 1);

    S1 := TextData[CurLine]^;
    S2 := TextData[CurLine + 1]^;

   If cfg_AutoIndent Then
     If (S2 = '') Then
       While S1[Indent] = ' ' Do Inc(Indent);

    S2 := strStripB(Copy(S1, CurX+ScrlX, 255) + S2, ' ');
    Delete (S1, CurX+ScrlX, 255);

    TextData[CurLine]^   := strStripR(S1, ' ');
    TextData[CurLine+1]^ := strRep(' ', Indent - 1) + S2;

    Inc (CurLine);

    ScrlX := 0;
    CurX  := Indent;

    If CurX > 77 Then Begin
      ScrlX := CurX - 77;
      CurX  := 77;
    End;

    If CurY < mideWinSize - 3 Then Begin
      Inc (CurY);
      DrawPage;
    End Else
      ScrollDown;

    Changed := True;
  End;
End;

Procedure AboutBox;
Var
  Box : TMenuBox;
Begin
  Box := TMenuBox.Create(Console);

  Box.Open (19, 7, 62, 19);

  Console.WriteXY (21,  8,  31, strPadC('MIDE', 40, ' '));
  Console.WriteXY (21,  9, 112, strRep('�', 40));
  Console.WriteXY (31, 12, 113, 'All Rights Reserved');
  Console.WriteXY (21, 14, 113, strPadC('Version ' + mideVersion + ' (MPL v' + mplVer + ')', 40, ' '));
  Console.WriteXY (32, 16, 113, 'www.vertigobbs.com');
  Console.WriteXY (21, 17, 112, strRep('�', 40));
  Console.WriteXY (21, 18,  31, strPadC('(PRESS A KEY)', 40, ' '));

  Input.ReadKey;

  Box.Close;
  Box.Free;
End;

Function DoMenu : Boolean;
Var
  Box   : TMenuBox;
  Saved : TConsoleImageRec;

  Procedure BoxOpen (X1, Y1, X2, Y2: Byte);
  Begin
    Box := TMenuBox.Create(Console);
    Box.Open(X1, Y1, X2, Y2);
  End;

  Procedure CoolBoxOpen (X1: Byte; Text: String);
  Var
    Len : Byte;
  Begin
    Len := Length(Text) + 6;

    Console.GetScreenImage(X1, 1, X1 + Len, 3, Saved);

    Console.WriteXYPipe (X1, 1, 8, Len, '�|15�|11��|03��|09�|03�|09' + strRep('�', Len - 9) + '|08�');
    Console.WriteXYPipe (X1 ,2, 8, Len, '�|09|17� |15' + Text + ' |00�|16|08�');
    Console.WriteXYPipe (X1, 3, 8, Len, '�|01�|17 |11�|03��|08' + strRep('�', Length(Text) - 4) + '|00� �|16|08�');
  End;

  Procedure BoxClose;
  Begin
    Box.Close;
    Box.Free;
  End;

  Procedure CoolBoxClose;
  Begin
    Console.PutScreenImage(Saved);
  End;

Var
  Form    : TMenuForm;
  Image   : TConsoleImageRec;
  MenuPtr : Byte;
  Res     : Char;
  Count   : LongInt;
  Str     : String;
  FN      : String;
  Key     : Char;
  TF      : Text;
  Make    : Boolean;
Begin
  Result := False;

  Console.GetScreenImage(1, 1, 80, 4, Image);

  Console.WriteXY (1, 1,  15, strRep('�', 80));
  Console.WriteXY (1, 2, 113, strRep(' ', 80));
  Console.WriteXY (1, 3,   8, strRep('�', 80));

  Form := TMenuForm.Create(Console);

  Form.HelpX     := 16;
  Form.HelpColor := 113;
  Form.HelpSize  := 52;
  Form.HelpY     := mideBotY + 1;

  MenuPtr := 0;

  Repeat
    Form.Clear;

    Form.ExitOnFirst := True;
    Form.ItemPos     := 1;

    If MenuPtr = 0 Then
      Form.HiExitChars := #80
    Else
      Form.HiExitChars := #75#77;

    Case MenuPtr of
      0 : Begin
            Form.AddNone ('F', ' File '   ,  4, 2, 6, 'File related options');
            Form.AddNone ('E', ' Edit '   , 16, 2, 6, 'File editing options');
            Form.AddNone ('C', ' Compile ', 28, 2, 9, 'MPL Compiler options');
            Form.AddNone ('O', ' Options ', 43, 2, 9, 'MIDE editor options');
            Form.AddNone ('W', ' Windows ', 58, 2, 9, 'Listing of currently opened windows');
            Form.AddNone ('H', ' Help '   , 72, 2, 6, 'MIDE help options');

            Res := Form.Execute;

            If Form.WasHiExit Then
              MenuPtr := Form.ItemPos
            Else
              Case Res of
                #27 : Break;
                'F' : MenuPtr := 1;
                'E' : MenuPtr := 2;
                'C' : MenuPtr := 3;
                'O' : MenuPtr := 4;
                'W' : MenuPtr := 5;
                'H' : MenuPtr := 6;
              End;
          End;
      1 : Begin
            CoolBoxOpen (2, 'File');
            BoxOpen (3, 4, 20, 12);

            Form.AddNone('N', '  New'          , 4,  5, 16, 'Create a new file');
            Form.AddNone('O', '  Open...    F3', 4,  6, 16, 'Open a new editor file/window');
            Form.AddNone('C', '  Close      F4', 4,  7, 16, 'Close current file/window');
            Form.AddNone('S', '  Save       F2', 4,  8, 16, 'Save current file/window');
            Form.AddNone('A', '  Save as...  ' , 4,  9, 16, 'Save/rename current file/window');
            Form.AddNone('L', '  Save all  '   , 4, 10, 16, 'Save all opened files');
            Form.AddNone('X', '  Exit      A+X', 4, 11, 16, 'Exit MIDE');

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 6;
                #77 : MenuPtr := 2;
              End
            Else
              Case Res of
                #27 : Break;
                'A' : Begin
                        SaveFile(CurWinNum, False, True);
                        Break;
                      End;
                'C' : Begin
                        CloseFile;
                        Exit;
                      End;
                'L' : Begin
                        For Count := 1 to 10 Do
                          SaveFile(Count, False, False);
                        Break;
                      End;
                'N' : Begin
                        Str  := InBox('New MPL Program', 'File Name:', 'new.mps', 50, 255);
                        Make := True;

                        If Str <> '' Then Begin
                          If FileExist(Str) Then
                            Make := ShowMsgBox(1, Str + ' exists.  Overwrite?');

                          If Make Then Begin
                            Assign  (TF, Str);
                            ReWrite (TF);
                            WriteLn (TF, '// New MPL Program');
                            Close   (TF);

                            Form.Free;
                            Console.PutScreenImage(Image);
                            LoadAndOpen(Str);
                            ReDrawScreen;
                            DrawStatus;
                            Exit;
                          End;
                        End;

                        Break;
                      End;
                'O' : Begin
                        Str := StartDir;
                        If OpenDialog('*.mps', Str, FN) Then Begin
                          Form.Free;
                          Console.PutScreenImage(Image);
                          LoadAndOpen(Str + FN);
                          ReDrawScreen;
                          DrawStatus;
                          Exit;
                        End;
                      End;
                'S' : Begin
                        SaveFile(CurWinNum, False, False);
                        Break;
                      End;
                'X' : Begin
                        Result := True;
                        Break;
                      End;
              Else
                MenuPtr := 0;
              End;
          End;
      2 : Begin
            CoolBoxOpen (14, 'Edit');
            BoxOpen (15, 4, 30, 7);

            Form.AddNone('F', '  Find  '      , 16,  5, 14, 'Search for text');
            Form.AddNone('R', '  Replace  '   , 16,  6, 14, 'Search and replace text');

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 1;
                #77 : MenuPtr := 3;
              End
            Else
              Case Res of
                #27 : Break;
                'M' : Begin
                      End;
              Else
                MenuPtr := 0;
              End;
          End;
      3 : Begin
            CoolBoxOpen (26, 'Compile');
            BoxOpen     (27, 4, 42, 7);

            Form.AddNone('R', '  Run      F8 '    , 28,  5, 14, 'Compile and then execute MPL program');
            Form.AddNone('C', '  Compile  F9 '    , 28,  6, 14, 'Compile current file into Vertigo executable');

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 2;
                #77 : MenuPtr := 4;
              End
            Else
              Case Res of
                #27 : Break;
                'C' : Begin
                        Console.PutScreenImage(Image);
                        Form.Free;
                        Compile;
                        DrawStatus;
                        Exit;
                      End;
                'R' : Begin
                        Console.PutScreenImage(Image);
                        Form.Free;
                        RunProgram;
                        DrawStatus;
                        Exit;
                      End;
              Else
                MenuPtr := 0;
              End;
          End;
      4 : Begin
            CoolBoxOpen (41, 'Options');
            BoxOpen (42, 4, 61, 6);

            Form.AddNone('E', '  Editor Options  ', 43, 5, 18, '');

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 3;
                #77 : MenuPtr := 5;
              End
            Else
              Case Res of
                #27 : Break;
                'E' : Begin
                        Console.PutScreenImage(Image);
                        Form.Free;
                        LoadAndOpen(StartDir + 'mide.ini');
                        ReDrawScreen;
                        DrawStatus;
                        Exit;
                      End;
              Else
                MenuPtr := 0;
              End;
          End;
      5 : Begin
            CoolBoxOpen (56, 'Windows');
            BoxOpen (37, 4, 77, 15);

            For Count := 1 to 10 Do Begin
              If Count = 10 Then Key := '0' Else Key := strI2S(Count)[1];
              If CurWin[Count] <> NIL Then
                Form.AddNone(Key, ' ' + Key + ' � ' + strPadR(CurWin[Count]^.FileName, 34, ' '), 38, 4 + Count, 39, CurWin[Count]^.FileName)
              Else
                Form.AddNone(Key, ' ' + Key + ' � Unassigned', 38, 4 + Count, 39, 'Window not opened');
            End;

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 4;
                #77 : MenuPtr := 6;
              End
            Else
              Case Res of
                '0'..
                '9' : Begin
                        If Res = '0' Then Count := 10 Else Count := strS2I(Res);
                        If CurWin[Count] <> NIL Then Begin
                          CurWinNum := Count;
                          Console.PutScreenImage(Image);
                          CurWin[Count]^.ReDrawFull;
                          DrawStatus;
                          Form.Free;
                          Exit;
                        End;
                      End;
                #27 : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      6 : Begin
            CoolBoxOpen (70, 'Help');
            BoxOpen (61, 4, 78, 9);

            Form.AddNone('A', '  About  '       , 62, 5, 16, 'About');
            Form.AddNone('I', '  Index  '       , 62, 6, 16, 'Open help at the main index');
            Form.AddNone('U', '  Under Cursor  ', 62, 7, 16, 'Search help for keyword under the cursor');
            Form.AddNone('H', '  Help on Help  ', 62, 8, 16, 'Help on using the help system');

            Res := Form.Execute;

            BoxClose;
            CoolBoxClose;

            If Form.WasHiExit Then
              Case Res of
                #75 : MenuPtr := 5;
                #77 : MenuPtr := 1;
              End
            Else
              Case Res of
                #27 : Break;
                'A' : Begin
                        AboutBox;
                        Break;
                      End;
              Else
                MenuPtr := 0;
              End;
          End;
    End;
  Until False;

  Form.Free;

  Console.PutScreenImage(Image);

  DrawStatus;
End;

Var
  Ch  : Char;
  A   : Byte;
  Str : String;
  FN  : String;
  INI : TINIReader;
Begin
  GetDir (0, StartDir);

  StartDir := StartDir + PathSep;

  Console := TOutput.Create(True);
  Input   := TInput.Create;

  Console.SetWindowTitle('MIDE');

  INI := TINIReader.Create('mide.ini');

  cfg_Screen50    := (INI.ReadInteger('General', 'screenmode', 25) = 50);
  cfg_TabSpaces   := INI.ReadInteger('General', 'tab_spaces', 2);
  cfg_AutoIndent  := strUpper(INI.ReadString('General', 'auto_indent', 'true')) = 'TRUE';
  cfg_Highlight   := strUpper(INI.ReadString('General', 'syntax_highlight', 'true')) = 'TRUE';
  cfg_ExecPath    := DirSlash(INI.ReadString('Execute', 'rootpath', ''));
  cfg_ExecUser    := INI.ReadString('Execute', 'username', 'Guest');
  cfg_ExecPW      := INI.ReadString('Execute', 'password', 'Guest');
  cfg_TextNormal  := INI.ReadInteger('Colors', 'syn_normal', 30);
  cfg_TextKeyword := INI.ReadInteger('Colors', 'syn_keyword', 31);
//  cfg_TextString  := INI.ReadInteger('Colors', 'syn_string', 27);
  cfg_TextNumber  := INI.ReadInteger('Colors', 'syn_number', 19);
  cfg_TextComment := INI.ReadInteger('Colors', 'syn_comment', 23);
  cfg_TextHex     := INI.ReadInteger('Colors', 'syn_hex', 28);
  cfg_TextCharStr := INI.ReadInteger('Colors', 'syn_charstr', 27);

  INI.Free;

  Str := ParamStr(1);

  If cfg_Screen50 Then Begin
    Console.SetScreenSize(50);

    mideBotY    := 49;
    mideWinSize := 49;
  End;

  FillScreen;

  TotalWinNum := 0;
  CurWinNum   := 0;

  If Str <> '' Then Begin
    If Pos(PathSep, Str) = 0 Then
      Str := StartDir + Str;

    If Pos('.', Str) = 0 Then
      Str := Str + '.mps';

    LoadAndOpen(Str);

    ReDrawScreen;
  End;

  Repeat
    If CurWinNum > 0 Then Begin
      With CurWin[CurWinNum]^ Do Begin
        Console.WriteXY ( 6, mideBotY, colEditBorder, strPadL(strI2S(CurLine), 4, '�') + ':' + strPadR(strI2S(CurX + ScrlX), 3, '�'));
        Console.WriteXY (80, BarPos, colEditStatus, '�');

        If CurLine = 1 Then
          BarPos := 2
        Else
        If CurLine = TotalLines Then
          BarPos := mideBotY - 1
        Else
          BarPos := Round(CurLine / TotalLines * (mideWinSize - 4)) + 3;

        Console.WriteXY  (80, BarPos, colEditPosBar, '�');
        Console.CursorXY (CurX + 1, CurY + 1);
      End;
    End;

    Ch := Input.ReadKey;

    Case Ch of
      #00 : Begin
              Ch := Input.ReadKey;

              Case Ch of
                #45 : Break;
                #60 : If TotalWinNum > 0 Then SaveFile(CurWinNum, False, False);
                #61 : If TotalWinNum < mideMaxOpenFiles Then Begin
                        Str := StartDir;
                        If OpenDialog('*.mps', Str, FN) Then Begin
                          LoadAndOpen(Str + FN);
                          ReDrawScreen;
                          DrawStatus;
                        End;
                      End;
                #62 : If TotalWinNum > 0 Then CloseFile;
//                #63 : SearchText(False);
//                #64 : SearchText(True);
                #66 : RunProgram;
                #67 : Compile;
                #71 : If CurWinNum > 0 Then Begin {home}
                        CurWin[CurWinNum]^.CurX := 1;
                        If CurWin[CurWinNum]^.ScrlX > 0 Then Begin
                          CurWin[CurWinNum]^.ScrlX := 0;
                          DrawPage;
                        End Else
                          CurWin[CurWinNum]^.ScrlX := 0;
                      End;
                #72 : UpArrow;
                #73 : PageUp;
                #75 : If CurWinNum > 0 Then Begin
                        With CurWin[CurWinNum]^ Do
                          If CurX = 1 Then Begin
                            If ScrlX > 0 Then Begin
                              Dec (ScrlX);
                              DrawPage;
                            End;
                          End Else
                            Dec (CurX);
                      End;
                #77 : RightArrow;
                #79 : If CurWinNum > 0 Then Begin {end}
                        CurWin[CurWinNum]^.CurX := Length(CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^) + 1;
                        If CurWin[CurWinNum]^.CurX > 77 Then
                          CurWin[CurWinNum]^.ScrlX := CurWin[CurWinNum]^.CurX - 77
                        Else
                          CurWin[CurWinNum]^.ScrlX := 0;

                        If CurWin[CurWinNum]^.ScrlX > 0 Then Begin
                          CurWin[CurWinNum]^.CurX := 77;
                          DrawPage;
                        End;
                      End;
                #80 : DownArrow;
                #81 : PageDown;
                #83 : DeleteChar;
                #120..
                #128: Begin
                        A := Ord(Ch) - 119;
                        If CurWin[A] <> NIL Then Begin
                          CurWinNum := A;
                          CurWin[A]^.ReDrawFull;
                        End;
                      End;
              End;
            End;
      ^K  : Begin
              If CutPasted Then Begin
                For A := CutTextPos DownTo 1 Do
                  Dispose (CutText[A]);

                CutTextPos := 0;
                CutPasted  := False;
              End;

              If CutTextPos < MaxCutText Then Begin
                Inc (CutTextPos);

                New (CutText[CutTextPos]);

                CutText[CutTextPos]^ := CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^;

                DeleteLine(True);
              End;
            End;
      ^U  : If CutTextPos > 0 Then Begin
              CutPasted := True;

              For A := CutTextPos DownTo 1 Do
                If CurWin[CurWinNum]^.TotalLines < mideMaxFileLines Then Begin
                  InsertLine(CurWin[CurWinNum]^.CurLine);
                  CurWin[CurWinNum]^.TextData[CurWin[CurWinNum]^.CurLine]^ := CutText[A]^;
                End;

              DrawPage;
            End;
      ^Y  : DeleteLine(True);
      #08 : BackSpace;
      #09 : InsertTab;
      #13 : Enter;
      #27 : If DoMenu Then Break;
      #32..
      #254: AddChar(Ch);
    End;
  Until False;

  While TotalWinNum > 0 Do CloseFile;

  For A := CutTextPos DownTo 1 Do
    Dispose (CutText[A]);

  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.WriteLine('Vertigo Integrated Development Environment Version ' + mideVersion);

  Input.Free;
  Console.Free;
End.
