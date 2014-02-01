{
  Copyright 2009-2013 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Container for 2D controls able to render using OpenGL (TGLContainer). }
unit CastleGLContainer;

{$I castleconf.inc}

interface

uses CastleUIControls;

type
  { Container for controls providing an OpenGL rendering.
    This class is internally used by TCastleWindowCustom and TCastleControlCustom.
    It is not useful from the outside, unless you want to implement
    your own container provider similar to TCastleWindowCustom / TCastleControlCustom. }
  TGLContainer = class abstract(TUIContainer)
  public
    procedure EventRender; override;
  end;

implementation

uses CastleVectors, CastleGL, CastleGLUtils;

procedure TGLContainer.EventRender;

  { Call Render for all controls having RenderStyle = rs3D.

    Also (since we call RenderStyle for everything anyway)
    calculates AnythingWants2D = if any control returned RenderStyle = rs2D.
    If not, you can later avoid even changing projection to 2D. }
  procedure Render3D(out AnythingWants2D: boolean);
  var
    I: Integer;
    C: TUIControl;
  begin
    AnythingWants2D := false;

    { draw controls in "downto" order, back to front }
    for I := Controls.Count - 1 downto 0 do
    begin
      C := Controls[I];
      if C.GetExists then
        case C.RenderStyle of
          rs2D: AnythingWants2D := true;
          { Set OpenGL state that may be changed carelessly, and has some
            guanteed value, for TUIControl.Render calls.
            For now, just glLoadIdentity. }
          rs3D: begin {$ifndef OpenGLES} glLoadIdentity; {$endif} C.Render; end;
        end;
    end;

    if TooltipVisible and (Focus <> nil) then
      case Focus.TooltipStyle of
        rs2D: AnythingWants2D := true;
        rs3D: begin {$ifndef OpenGLES} glLoadIdentity; {$endif} Focus.TooltipRender; end;
      end;

    case RenderStyle of
      rs2D: AnythingWants2D := true;
      rs3D: begin {$ifndef OpenGLES} glLoadIdentity; {$endif} if Assigned(OnRender) then OnRender(Self); end;
    end;
  end;

  procedure Render2D;
  var
    C: TUIControl;
    I: Integer;
  begin
    { Set state that is guaranteed for Render2D calls,
      but TUIControl.Render cannot change it carelessly. }
    {$ifndef OpenGLES}
    glDisable(GL_LIGHTING);
    glDisable(GL_FOG);
    {$endif}
    glDisable(GL_DEPTH_TEST);
    ScissorDisable;
    GLEnableTexture(CastleGLUtils.etNone);
    glViewport(Rect);

    OrthoProjection(0, Width, 0, Height);

    { draw controls in "downto" order, back to front }
    for I := Controls.Count - 1 downto 0 do
    begin
      C := Controls[I];
      if C.GetExists and (C.RenderStyle = rs2D) then
      begin
        { Set OpenGL state that may be changed carelessly, and has some
          guanteed value, for Render2d calls. }
        {$ifndef OpenGLES} glLoadIdentity; {$endif}
        CastleGLUtils.WindowPos := Vector2LongInt(0, 0);
        C.Render;
      end;
    end;

    if TooltipVisible and (Focus <> nil) and (Focus.TooltipStyle = rs2D) then
    begin
      {$ifndef OpenGLES} glLoadIdentity; {$endif}
      CastleGLUtils.WindowPos := Vector2LongInt(0, 0);
      Focus.TooltipRender;
    end;

    if RenderStyle = rs2D then
    begin
      {$ifndef OpenGLES} glLoadIdentity; {$endif}
      CastleGLUtils.WindowPos := Vector2LongInt(0, 0);
      if Assigned(OnRender) then OnRender(Self);
    end;
  end;

var
  AnythingWants2D: boolean;
begin
  Render3D(AnythingWants2D);

  if AnythingWants2D then
    Render2D;
end;

end.
