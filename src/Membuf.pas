unit Membuf;

// A growable continuous in-memory buffer in pure Object Pascal/Delphi.
// https://github.com/liigo/membuf.pas
// Liigo, 201603.


interface

uses SysUtils;

type
  TMembuf = class
  private
    FData: PByte;
    FSize: Integer;
    FBufSize: Integer;

  public
    constructor Create(BufSize: Integer; const InitBytes: array of Byte); overload;
    destructor  Destroy(); override;
    function Size(): Integer;
    function Data(): PByte;
    function DataOffset(Offset: Integer): PByte;
    procedure Reserve(ExtraSize: Integer);
    procedure AppendByte(v: Byte);
    procedure AppendBytes(const Bytes: array of Byte);
    procedure AppendData(Data: Pointer; Size: Integer);
    procedure AppendIntegers(const Integers: array of Integer);
    procedure AppendDoubles(const Doubles: array of Double);
    function InsertByte(Offset: Integer; Value: Byte): Boolean;
    function InsertBytes(Offset: Integer; const Bytes: array of Byte): Boolean;
    function InsertData(Offset: Integer; Data: Pointer; Size: Integer): Boolean;
    function Remove(Offset: Integer; Size: Integer): Boolean;
    procedure Clear();
    function ByteAt(Offset: Integer): Byte;
    function UncheckedByteAt(Offset: Integer): Byte;
    function ByteSet(Offset: Integer; Value: Byte): Boolean;
    function UncheckedByteSet(Offset: Integer; Value: Byte): Boolean;
    function SearchByte(Offset: Integer; Value: Byte): Integer;
    function VerifyBytes(Offset: Integer; Bytes: array of Byte): Boolean;
    function IsValidOffsetSize(Offset, Size: Integer): Boolean;

  end;

implementation

{ TMembuf }
            
constructor TMembuf.Create(BufSize: Integer; const InitBytes: array of Byte);
begin
  FData := nil;
  FSize := 0;
  FBufSize := BufSize;
  if BufSize > 0 then begin
    ReallocMem(FData, FBufSize);
  end;
  AppendBytes(InitBytes);
end;

destructor TMembuf.Destroy;
begin
  if FData <> nil then begin
    FreeMem(FData);
    FData := nil;
  end;
  FSize := 0;
  FBufSize := 0;
end;

function CalcNewBufSize(BufSize, Size, ExtraSize: Integer): Integer;
var
  NewBufSize: Integer;
begin
  if BufSize <> 0 then begin
    NewBufSize := BufSize;
  end else begin
    NewBufSize := ExtraSize;
  end;
  while NewBufSize < Size + ExtraSize do begin
    NewBufSize := NewBufSize shl 1;
  end;
  Result := NewBufSize;
end;

procedure TMembuf.Reserve(ExtraSize: Integer);
begin
  if (FData = nil) or (FBufSize - FSize < ExtraSize) then begin
    FBufSize := CalcNewBufSize(FBufSize, FSize, ExtraSize);
    ReallocMem(FData, FBufSize);
  end;
end;

function PtrOffset(Ptr: Pointer; Offset: Integer): PByte;
begin
  Result := PByte(Int64(Ptr) + Offset);
end;

procedure TMembuf.AppendByte(v: Byte);
begin
  AppendData(@v, 1);
end;

procedure TMembuf.AppendBytes(const Bytes: array of Byte);
var
  Data: PByte;
begin
  Data := @Bytes[0];
  AppendData(Data, Length(Bytes));
end;

procedure TMembuf.AppendData(Data: Pointer; Size: Integer);
var
  DestPtr: PByte;
begin
  Reserve(Size);
  DestPtr := PtrOffset(FData, FSize);
  // Liigo 20160330: Move()'s interface and definition are both sick.
  // See source code of Move() and StrMove().
  StrMove(PChar(DestPtr), PChar(Data), Size);
  FSize := FSize + Size;
end;

function TMembuf.InsertByte(Offset: Integer; Value: Byte): Boolean;
begin
  Result := InsertData(Offset, @Value, 1);
end;

function TMembuf.InsertBytes(Offset: Integer; const Bytes: array of Byte): Boolean;
var
  Data: Pointer;
begin
  Data := @Bytes[0];
  Result := InsertData(Offset, Data, Length(Bytes));
end;

function TMembuf.InsertData(Offset: Integer; Data: Pointer; Size: Integer): Boolean;
var Ptr1, Ptr2: PByte;
begin
  Result := false;
  if (Offset < 0) or (Offset > FSize) then Exit;
  if Size = 0 then begin Result := true; Exit; end;
  if (FSize = 0) or (Offset = FSize) then begin
    AppendData(Data, Size);
    Result := true;
    Exit;
  end;
  //   /........../********/..........
  //              Ptr1     Ptr2
  Reserve(Size);
  Ptr1 := DataOffset(Offset);
  Ptr2 := DataOffset(Offset + Size);
  StrMove(PChar(Ptr2), PChar(Ptr1), FSize - Offset);
  StrMove(PChar(Ptr1), PChar(Data), Size);
  FSize := FSize + Size;
  Result := true;
end;

function TMembuf.Remove(Offset, Size: Integer): Boolean;
var
  SrcPtr, DestPtr: PByte;
  Count: Integer;
begin
  Result := false;
  if not IsValidOffsetSize(Offset, Size) then Exit;
  Count := FSize - Offset - Size;
  if Count > 0 then begin
    SrcPtr  := DataOffset(Offset + Size);
    DestPtr := DataOffset(Offset);
    StrMove(PChar(DestPtr), PChar(SrcPtr), Count);
  end;
  FSize := FSize - Size;
  Result := true;
end;

// raise ERangeError if no valid byte at the index
function TMembuf.ByteAt(Offset: Integer): Byte;
begin
  if not IsValidOffsetSize(Offset, 1) then begin
    raise ERangeError.CreateFmt('Offset %d out of range [0..%d] TMembuf.ByteAt()',
                                [Offset, FSize-1]);
  end;
  Result := UncheckedByteAt(Offset);
end;

function TMembuf.UncheckedByteAt(Offset: Integer): Byte;
begin
  Result := PtrOffset(FData, Offset)^;
end;

function TMembuf.Size: Integer;
begin
  Result := FSize;
end;

function TMembuf.Data: PByte;
begin
  Result := FData;
end;

// Keep offset safe yourself!
function TMembuf.DataOffset(Offset: Integer): PByte;
begin
  Result := PtrOffset(FData, Offset);
end;

function TMembuf.VerifyBytes(Offset: Integer; Bytes: array of Byte): Boolean;
var
  Len, i: Integer;
begin
  Result := false;
  Len := Length(Bytes);
  if not IsValidOffsetSize(Offset, Len) then begin
    Exit;
  end;
  for i:=0 to Len-1 do begin
    if UncheckedByteAt(Offset + i) <> Bytes[i] then begin
      Exit;
    end;
  end;
  Result := true;
end;

function TMembuf.IsValidOffsetSize(Offset, Size: Integer): Boolean;
begin
  Result := (FData <> nil) and (Offset + Size <= FSize)
            and (Offset >= 0) and (Size >= 0);
end;

procedure TMembuf.Clear;
begin
  FSize := 0;
end;

function TMembuf.ByteSet(Offset: Integer; Value: Byte): Boolean;
begin
  Result := false;
  if not IsValidOffsetSize(Offset, 1) then Exit;
  Result := UncheckedByteSet(Offset, Value);
end;

function TMembuf.UncheckedByteSet(Offset: Integer; Value: Byte): Boolean;
begin
  PtrOffset(FData, Offset)^ := Value;
  Result := true;
end;

function TMembuf.SearchByte(Offset: Integer; Value: Byte): Integer;
var
  i: Integer;
  Ptr: PByte;
begin
  Result := -1;
  if not IsValidOffsetSize(Offset, 1) then Exit;
  // TODO: find a more efficency way
  Ptr := DataOffset(Offset);
  for i:=0 to FSize-Offset-1 do begin
    if PtrOffset(Ptr, i)^ = Value then begin
      Result := Offset + i;
      break;
    end;
  end;
end;

procedure TMembuf.AppendIntegers(const Integers: array of Integer);
var
  Data: PByte;
begin
  Data := @Integers[0];
  AppendData(Data, Length(Integers) * SizeOf(Integer));
end;

procedure TMembuf.AppendDoubles(const Doubles: array of Double);
var
  Data: PByte;
begin
  Data := @Doubles[0];
  AppendData(Data, Length(Doubles) * SizeOf(Double));
end;

end.
