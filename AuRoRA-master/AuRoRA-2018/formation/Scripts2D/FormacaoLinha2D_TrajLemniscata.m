%% CONTROLE DE TRAJET?RIA PARA FORMA??O DE DOIS ROB?S EM LINHA

clear
close all
clc
% Fecha todas poss?veis conex?es abertas
try
    fclose(instrfindall);
catch
end

%% Rotina para buscar pasta raiz
PastaAtual = pwd;
PastaRaiz = 'AuRoRA 2018';
cd(PastaAtual(1:(strfind(PastaAtual,PastaRaiz)+numel(PastaRaiz)-1)))
addpath(genpath(pwd))

%% Defini??o da janela do gr?fico
fig = figure(1);
axis([-4 4 -4 4])
pause(1)

%% Cria??o dos rob?s
idA = input('Digite o ID do rob?: ');
if idA == 1
    idB = 2;
elseif idA == 2
    idB = 1;
end
% PB = Pioneer3DX(idB);

PA = Pioneer3DX(idA);
PB = Pioneer3DX;

%% Posi??o inicial dos rob?s
Xo = input('Digite a posi??o inicial do rob? ([x y z psi]): ');

%% Gravar arquivos de txt (ou excel)
% Apenas o rob? 1 ir? gravar os dados para evitar redund?ncia
NomeArq = datestr(now,30);
cd('DataFiles')
cd('Log_FormacaoLinha2D')
Arq = fopen(['FL2dtrajLemniSim_' NomeArq '.txt'],'w');
cd(PastaAtual)

%% Conex?o com rob?/simulador
PA.rConnect;             % rob? ou mobilesim
PA.rSetPose(Xo);         % define pose do rob?
% pause(3)
disp('In?cio..............')

%% Defini??o da Forma??o
% centro de refer?ncia da forma??o:
% center = ponto m?dio entre os rob?s
% robot  = refer?ncia no rob? 1
% type = 'center';
type = 'center';
LF = LineFormation2D(type);       % carrega classe forma??o 2D
LF.pPos.Qd = [0 0 1 0]'; % define forma??o desejada

% LF.pPar.K1 = 1*diag([.4 .4 0.6 1.5]);          % ganho controlador cinem?tico
% LF.pPar.K2 = 1*diag([.5 .5 .5 .5]);              % ganho controlador cinem?tico

%% Cria??o da rede
Rede = NetDataShare;

%% Network communication check
disp('Begin network check......')
tm = tic;
while true
    Rede.mSendMsg(PA);
    if isempty(Rede.pMSG.getFrom)
        Rede.mSendMsg(PA);
        if toc(tm) > 0.1
            tm = tic;
            Rede.mReceiveMsg;
            disp('Waiting for message......')
        end
    elseif length(Rede.pMSG.getFrom) > 1
        if isempty(Rede.pMSG.getFrom{idB})
            tm = tic;
            Rede.mSendMsg(PA);           
            Rede.mReceiveMsg;
            disp('Waiting for message......')
            
        else
            break
        end
    end
    Rede.mReceiveMsg;
end
clc
disp('Data received. Proceding program...');

%% Inicializa??o de vari?veis
Xa = PA.pPos.X(1:6);    % postura anterior
data = [];
Rastro.Qd = [];
Rastro.Q = [];

%% Trajet?ria
a = 3;         % dist?ncia em x
b = 1.5;         % dist?ncia em y
w = 0.1;

nvoltas = 1.5;
tsim = 2*pi*nvoltas/w;
tap = .1;     % taxa de atualiza??o do pioneer

%% C?lculo do erro inicial da forma??o
if length(Rede.pMSG.getFrom) >= 1
    if PA.pID > 1       % Caso robo seja ID = 2
        
        % pegar primeiro robo
        if ~isempty(Rede.pMSG.getFrom{1})
            
            Xa = Rede.pMSG.getFrom{1}(14+(1:6)); % rob? 1
            Xb = PA.pPos.X((1:6));                % rob? 2

%             PB.rSetPose(Xa([1 2 3 6]));        % define pose do rob? B
            
            % Posi??o inicial dos rob?s
            LF.pPos.X = [Xa; Xb];
            
        end
    else    % Caso o rob? seja o ID = 1
        
        if length(Rede.pMSG.getFrom) == PA.pID+1   % caso haja dados dos dois rob?s na rede
            
            Xa = PA.pPos.X(1:6);                         % rob? 1
            Xb = Rede.pMSG.getFrom{PA.pID+1}(14+(1:6));  % rob? 2
            
%             PB.rSetPose(Xb([1 2 3 6]));        % define pose do rob? B

            % Posi??o inicial dos rob?s
            LF.pPos.X = [Xa; Xb];
            
        end
    end
end

% Posi??o inicial da forma??o
LF.mDirTrans;

% Erro da forma??o
LF.pPos.Qtil = LF.pPos.Qd - LF.pPos.Q;
% Tratamento de quadrante
if abs(LF.pPos.Qtil(4)) > pi
    if LF.pPos.Qtil(4) > 0
        LF.pPos.Qtil(4) = -2*pi + LF.pPos.Qtil(4);
    else
        LF.pPos.Qtil(4) =  2*pi + LF.pPos.Qtil(4);
    end
end

%% Simula??o

% Temporiza??o
timeout = 120;   % tempo m?ximo de dura??o da simula??o
t = tic;
tc = tic;
tp = tic;

while toc(t) < tsim
    
    if toc(tc) > tap
        
        tc = tic;
        
        % Calculo da trajet?ria
        %         % infinito (8')
                 ta = toc(t);
                LF.pPos.Qd(1)  = a*sin(w*ta);       % posi??o x
                LF.pPos.Qd(2)  = b*sin(2*w*ta);     % posi??o y
                LF.pPos.dQd(1) = a*w*cos(w*ta);     % velocidade em x
                LF.pPos.dQd(2) = 2*b*w*cos(2*w*ta); % velocidade em y
       
        % Angulo da forma??o seguindo a trajetoria
        LF.pPos.Qd(4) = atan2(LF.pPos.dQd(2),LF.pPos.dQd(1)) + pi/2;        
        LF.pPos.dQd(4) = 1/(1+(LF.pPos.dQd(2)/LF.pPos.dQd(1))^2)* ...
           ((LF.pPos.dQd(2)*LF.pPos.Qd(1)-LF.pPos.Qd(2)*LF.pPos.dQd(1))/LF.pPos.Qd(1)^2);
    
       %         c?rculo
%         ta = toc(t);
%         LF.pPos.Qd(1)  = a*cos(w*ta);    % posi??o x
%         LF.pPos.Qd(2)  = b*sin(w*ta);    % posi??o y
%         LF.pPos.dQd(1) = -a*w*sin(w*ta);  % velocidade em x
%         LF.pPos.dQd(2) = b*w*cos(w*ta); % velocidade em y
        
        % ?ngulo da forma??o seguindo a trajet?ria
%         LF.pPos.Qd(4) = w*ta; 
%         LF.pPos.dQd(4) = ta; 
        
        % salva vari?veis para plotar no gr?fico
        Rastro.Qd = [Rastro.Qd; LF.pPos.Qd(1:2)'];  % forma??o desejada
        Rastro.Q  = [Rastro.Q; LF.pPos.Q(1:2)'];    % forma??o real
        
        % Pega dados dos sensores
        PA.rGetSensorData;
        
        % L? dados da rede
        Rede.mReceiveMsg;
        
        % Buscar SEMPRE rob? com ID+1 para forma??o
        % Vari?vel rob?s da rede
        % Verifica se h? mensagem
        %% Controle de forma??o
        if length(Rede.pMSG.getFrom) >= 1
            % Caso robo seja ID = 2 .....................................
            if  PA.pID > 1
                
                % pegar primeiro robo
                if ~isempty(Rede.pMSG.getFrom{1})
                    
                    Xa = Rede.pMSG.getFrom{1}(14+(1:6));    % rob? 1
                    Xb = PA.pPos.X(1:6);                     % rob? 2
                    
                    % Pose da forma??o
                    LF.pPos.X = [Xa; Xb];
                    
                    % Controlador da forma??o
                    LF.mFormationControl;
                    
                    % Posi??o desejada
                    LF.mInvTrans('d');  % obtem posi??es desejadas dos rob?s
                    PA.pPos.Xd(1:2) = LF.pPos.Xd(3:4);
                    
                    % Atribui sinal de controle ao rob?
                    PA.sInvKinematicModel(LF.pPos.dXr(3:4));
                    
                    % Atribuindo valores desejados do controle de forma??o
                    PB.pPos.Xd = Rede.pMSG.getFrom{1}(2+(1:12));
                    PB.pPos.X  = Rede.pMSG.getFrom{1}(14+(1:12));
                    PB.pSC.Ud  = Rede.pMSG.getFrom{1}(26+(1:2));
                    PB.pSC.U   = Rede.pMSG.getFrom{1}(28+(1:2));
                    
                    % Postura do centro do rob?
                    PB.pPos.Xc([1 2 6]) = PB.pPos.X([1 2 6]) - ...
                        [PB.pPar.a*cos(PB.pPos.X(6)); PB.pPar.a*sin(PB.pPos.X(6)); 0];
                    
                    % Armazenar dados no arquivo de texto
                    %                     if ID==1
                    fprintf(Arq,'%6.6f\t',[PA.pPos.Xd' PA.pPos.X' PA.pSC.Ud' PA.pSC.U' ...
                        PB.pPos.Xd' PB.pPos.X' PB.pSC.Ud' PB.pSC.U' LF.pPos.Qd' LF.pPos.Qtil' toc(t)]);
                    fprintf(Arq,'\n\r');
                    %                     end
                end
                
                % Caso o rob? seja o ID = 1 ..................................
            else
                
                if length(Rede.pMSG.getFrom) == PA.pID+1   % caso haja dados dos dois rob?s na rede
                    
                    Xa = PA.pPos.X(1:6);                         % rob? 1
                    Xb = Rede.pMSG.getFrom{PA.pID+1}(14+(1:6));  % rob? 2
                    
                    % Posi??o dos rob?s
                    LF.pPos.X = [Xa; Xb];
                    
                    % Controlador da forma??o
                    LF.mFormationControl;
                    
                    % Posi??o desejada
                    LF.mInvTrans('d');  % obtem posi??es desejadas dos rob?s
                    PA.pPos.Xd(1:2) = LF.pPos.Xd(1:2);
                    
                    % Atribui sinal de controle
                    PA.sInvKinematicModel(LF.pPos.dXr(1:2));
                    
                    % Atribuindo valores desejados do controle de forma??o
                    PB.pPos.Xd = Rede.pMSG.getFrom{PA.pID+1}(2+(1:12));
                    PB.pPos.X  = Rede.pMSG.getFrom{PA.pID+1}(14+(1:12));
                    PB.pSC.Ud  = Rede.pMSG.getFrom{PA.pID+1}(26+(1:2));
                    PB.pSC.U   = Rede.pMSG.getFrom{PA.pID+1}(28+(1:2));
                    
                    % Postura do centro do rob?
                    PB.pPos.Xc([1 2 6]) = PB.pPos.X([1 2 6]) - ...
                        [PB.pPar.a*cos(PB.pPos.X(6)); PB.pPar.a*sin(PB.pPos.X(6)); 0];
                    
                    % Armazenar dados no arquivo de texto
                 
                    fprintf(Arq,'%6.6f\t',[PA.pPos.Xd' PA.pPos.X' PA.pSC.Ud' PA.pSC.U' ...
                        PB.pPos.Xd' PB.pPos.X' PB.pSC.Ud' PB.pSC.U' LF.pPos.Qd' LF.pPos.Qtil' toc(t)]);
                    fprintf(Arq,'\n\r');
               
                end
            end
        end
        
        %% Compensa??o din?mica
        % Compensador din?mico
        PA = fCompensadorDinamico(PA);

      
        % vari?vel para plotar gr?ficos
        data = [data; PA.pPos.Xd' PA.pPos.X' PA.pSC.Ud' PA.pSC.U' ...
            PB.pPos.Xd' PB.pPos.X' PB.pSC.Ud' PB.pSC.U' LF.pPos.Qd' LF.pPos.Qtil' toc(t)];
        
        % Publicar mensagem na rede
        Rede.mSendMsg(PA);
        
        %% Envia sinais de controle
        PA.rSendControlSignals;
        
    end
    
    % Desenha os rob?s
    
    if toc(tp) > tap
        tp = tic;
        try
            PA.mCADdel
            PB.mCADdel
            delete(fig);
            delete(fig2);
        catch
        end
        PA.mCADplot2D('b')
        PB.mCADplot2D('r')
        hold on
        fig = plot(Rastro.Qd(:,1),Rastro.Qd(:,2),'k');
        fig2 = plot(Rastro.Q(:,1),Rastro.Q(:,2),'g');
        axis([-8 8 -8 8])
        grid on
        drawnow
    end
    
end

%% Fechar e Parar
% if ID==1
fclose(Arq);
% end

% Zera velocidades do rob?
PA.pSC.Ud = [0 ; 0];
PA.rSendControlSignals;

%% Resultados
% Verifica qual rob? ? qual para que os gr?ficos fiquem iguais
%  nos dois computadores
if PA.pID == 1
    plotResultsTraj(PA,PB,LF,data);
elseif PA.pID == 2
    plotResultsTraj(PB,PA,LF,data);
end