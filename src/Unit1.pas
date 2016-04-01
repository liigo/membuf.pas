unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Membuf;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    procedure VerifyMembuf(Membuf: TMembuf; Offset: Integer; Bytes: array of Byte; Desc: String = '');
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.VerifyMembuf(Membuf: TMembuf; Offset: Integer; Bytes: array of Byte; Desc: String = '');
begin
  if Membuf.VerifyBytes(Offset, Bytes) then begin
    Memo1.Lines.Add('Membuf Verify OK£º' + Desc);
  end else begin
    Memo1.Lines.Add('Membuf Verify FAIL: ' + Desc + ' !!!!!!!!!!!!!');
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  buf1: TMembuf;
  i: Integer;
  ExceptionRaised: Boolean;
begin

  buf1 := TMembuf.Create(0, [0,1,2,3,4]);
  VerifyMembuf(buf1, 0, [0,1,2,3,4], 'init');
  buf1.AppendBytes([7,8,9]);
  VerifyMembuf(buf1, 0, [0,1,2,3,4, 7,8,9], 'append');
  buf1.AppendBytes([]);
  VerifyMembuf(buf1, 0, [0,1,2,3,4, 7,8,9], 'append []');
  buf1.InsertBytes(5, [5,6]);
  VerifyMembuf(buf1, 0, [0,1,2,3,4, 5,6, 7,8,9], 'insert');
  buf1.AppendBytes([101, 102, 103, 104, 105, 106]);
  VerifyMembuf(buf1, 10, [101, 102, 103, 104, 105, 106], 'append2,realloc');
  buf1.Remove(0, 10);
  VerifyMembuf(buf1, 0, [101, 102, 103, 104, 105, 106], 'remove');
  buf1.AppendByte(108);
  VerifyMembuf(buf1, 0, [101, 102, 103, 104, 105, 106, 108], 'append byte');
  buf1.InsertByte(6, 107);
  VerifyMembuf(buf1, 0, [101, 102, 103, 104, 105, 106, 107, 108], 'insert byte');
  buf1.InsertByte(8, 109);
  VerifyMembuf(buf1, 0, [101, 102, 103, 104, 105, 106, 107, 108, 109], 'insert byte tail');
  assert(buf1.Size() = 9);

  // test remove
  buf1.Clear();
  VerifyMembuf(buf1, 0, [], 'clear');
  buf1.AppendBytes([0,1,2,3,4,5,6,7,8,9]);
  buf1.Remove(8, 2);
  VerifyMembuf(buf1, 0, [0,1,2,3,4,5,6,7], 'remove tail');
  buf1.Remove(4, 3);
  VerifyMembuf(buf1, 0, [0,1,2,3,7], 'remove mid');
  buf1.Remove(0, 4);
  VerifyMembuf(buf1, 0, [7], 'remove head');
  assert(buf1.Size() = 1);

  // test insert
  buf1.Clear();
  buf1.AppendBytes([1,2,3]);
  buf1.InsertBytes(0, [0]);
  VerifyMembuf(buf1, 0, [0, 1,2,3], 'insert head');
  buf1.InsertBytes(4, [4]);
  VerifyMembuf(buf1, 0, [0,1,2,3, 4], 'insert tail');
  buf1.InsertBytes(2, [9,9,9]);
  VerifyMembuf(buf1, 0, [0,1, 9,9,9, 2,3,4], 'insert mid');
  assert(buf1.Size() = 8);

  // test ByteAt(), ByteSet()
  buf1.Clear();
  buf1.AppendBytes([6, 6, 6]);
  assert(buf1.ByteSet(0, 0));
  assert(buf1.ByteAt(0) = 0);
  assert(buf1.ByteSet(1, 1));
  assert(buf1.ByteAt(1) = 1);
  assert(buf1.ByteSet(2, 2));
  assert(buf1.ByteAt(2) = 2);

  ExceptionRaised := false;
  try
    buf1.ByteAt(3);
  except
    on e: ERangeError do begin
      ExceptionRaised := true;
      Memo1.Lines.Add('Expected ERangeError OK: ' + e.Message);
    end;
  end;
  assert(ExceptionRaised, 'invalid offset');

  assert(not buf1.ByteSet(3, 6), 'invalid offset');
  assert(not buf1.ByteSet(-1, 6), 'invalid offset');
  VerifyMembuf(buf1, 0, [0, 1, 2], 'ByteAt ByteSet');
  assert(buf1.Size() = 3);

  // test SearchByte
  buf1.Clear();
  buf1.AppendBytes([0,1,2,3,0, 1,9]);
  assert(buf1.SearchByte(0, 0) = 0, 'search head');
  assert(buf1.SearchByte(0, 1) = 1, 'search normal');
  assert(buf1.SearchByte(1, 1) = 1, 'search at the offset');
  assert(buf1.SearchByte(2, 1) = 5, 'search the second 1');
  assert(buf1.SearchByte(0, 9) = 6, 'search tail');
  assert(buf1.SearchByte(0, 4)  = -1, 'value not exist');
  assert(buf1.SearchByte(-1, 0) = -1, 'invalid offset');
  VerifyMembuf(buf1, 0, [0,1,2,3,0, 1,9], 'search not change the buf');
  assert(buf1.Size() = 7);

  // append many bytes
  buf1.Clear();
  for i:=0 to 10000 do begin
    buf1.AppendBytes([i mod 256]);
  end;
  VerifyMembuf(buf1, 0, [0,1,2,3], 'big loop 0');
  VerifyMembuf(buf1, 99, [99,100,101], 'big loop 99');
  VerifyMembuf(buf1, 255, [255,0,1,2], 'big loop 255');
  VerifyMembuf(buf1, 4096, [0,1,2], 'big loop 496');
  assert(buf1.Size() = 10001);

  buf1.Free();

end;

end.

