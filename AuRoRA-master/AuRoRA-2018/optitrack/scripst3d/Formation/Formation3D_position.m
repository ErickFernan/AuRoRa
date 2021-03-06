%% 3D Line Formation Pioneer-Drone
% Position task using a 3D line virtual structure to control the formation
%
% I.   Pioneer is the reference of the formation
% II.  The formation variables are:
%      Q = [xf yf zf rhof alfaf betaf]

clear
close all
clc

try
    fclose(instrfindall);
catch
end

%% Look for root folder
PastaAtual = pwd;
PastaRaiz = 'AuRoRA 2018';
cd(PastaAtual(1:(strfind(PastaAtual,PastaRaiz)+numel(PastaRaiz)-1)))
addpath(genpath(pwd))


%% Load Classes
% Robot
P = Pioneer3DX(1);
% P.pPar.a = 0.1;
A = ArDrone(2);
A.pPar.Ts = 1/30;
% kx1 kx2 ky1 ky2 kz1 kz2 ; kPhi1 kPhi2 ktheta1 ktheta2 kPsi1 kPsi2
gains = [0.5 3 0.6 3 2 15; 10 3 8 3 1 4];

% Formation 3D
LF = LineFormation3D;
% Ganho do controlador de trajetória
LF.pPar.K1 = 1*diag([0.4 0.4 0.5 1.5 0.75 0.6]);    % kinematic amplitude gain  
LF.pPar.K2 = 1*diag([0.2 0.2 0.5 0.82 0.6 1.57]);   % kinematic saturation gain 

% Joystick
J = JoyControl;

% Create OptiTrack object and initialize
OPT = OptiTrack;
OPT.Initialize;

% Network
Rede = NetDataShare;

%% Open file to save data
NomeArq = datestr(now,30);
cd('DataFiles')
cd('Log_Optitrack')
Arq = fopen(['FL3d_PositionExp' NomeArq '.txt'],'w');
cd(PastaAtual)

%% Network communication check
tm = tic;
while true
    
    if isempty(Rede.pMSG.getFrom)
        Rede.mSendMsg(P);
        if toc(tm) > 0.1
            tm = tic;
            Rede.mReceiveMsg;
            disp('Waiting for message......')
        end
    elseif length(Rede.pMSG.getFrom) > 1
        if isempty(Rede.pMSG.getFrom{2})
            Rede.mSendMsg(P);
            
            tm = tic;
            Rede.mReceiveMsg;
            disp('Waiting for message......')
            
        else
            break
        end
    end
end
clc
disp('Data received. Continuing program...');

%% Robot/Simulator conection
A.rConnect;

%% Robots initial pose
% detect rigid body ID from optitrack
idP = getID(OPT,P);         % pioneer ID on optitrack
idA = getID(OPT,A);         % drone ID on optitrack

rb = OPT.RigidBody;          % read optitrack data
A = getOptData(rb(idA),A);   % get ardrone data
P = getOptData(rb(idP),P);   % get pioneer data

A.rTakeOff;
pause(5)                     % time to drone stabilize
disp('READY?? GO! GO! GO!');

%% Variable initialization
% Saves data to plot
data = [];
% Desired positions vector [xf yf zf rho alpha beta]
Qd = [  1.2  0.5  0   1.7     deg2rad(-120)  pi/4;
       -1.2  0.5  0   1.5     0     pi/2;
        0.5    -1   0   1.2     pi/2      pi/3;
        0     0    0   1.5       0     pi/2];


cont = 0;     % counter to change desired position through simulation
time = 15;    % time to change desired positions [s]
% First desired position
LF.pPos.Qd = Qd(1,:)';
% Robots desired pose
LF.mInvTrans;
%% Formation initial error
% Formation initial pose
LF.pPos.X = [P.pPos.X(1:3); A.pPos.X(1:3)];

% Formation initial pose
LF.mDirTrans;

% Formation Error
LF.mFormationError;

%% Simulation
% Maximum error permitted
erroMax = [.1 .1 0 .1 deg2rad(5) deg2rad(5)];

% Time variables initialization
% timeout = 60;   % maximum simulation duration
tsim =  size(Qd,1)*(time);
t  = tic;
tc = tic;
tp = tic;
t1 = tic;        % pioneer cycle
t2 = tic;        % ardrone cycle

while toc(t)< tsim
    
    if toc(tc) > 1/30        
        tc = tic;
            %% Desired positions
    if toc(t)> cont*time
        cont = cont + 1;
    end
    
    if cont <= size(Qd,1)
        LF.pPos.Qd = Qd(cont,:)';
    end
        LF.pPos.Qd(5)  = Qd(cont,5) + P.pPos.X(6);  % alpha angle
        %% Acquire sensors data
        % Get network data
        Rede.mReceiveMsg;
        if length(Rede.pMSG.getFrom)>1
            P.pSC.U  = Rede.pMSG.getFrom{2}(29:30);  % current velocities (robot sensors)
            PX       = Rede.pMSG.getFrom{2}(14+(1:12));   % current position (robot sensors)
        end
        
        % Get optitrack data
        rb = OPT.RigidBody;             % read optitrack
        % Ardrone
        A       = getOptData(rb(idA),A);
        A.pSC.U = [A.pPos.X(4);A.pPos.X(5);A.pPos.X(9);A.pPos.X(12)]; % populates actual control signal to save data
        % Pioneer
        P = getOptData(rb(idP),P);
        
        %% Control
        % Formation Members Position
        LF.pPos.X = [P.pPos.X(1:3); A.pPos.X(1:3)];
        
        % Formation Controller
        LF.mFormationControl;
        
        % Desired positions ...........................................
        LF.mInvTrans;
        % Pioneer
        P.pPos.Xd(1:3) = LF.pPos.Xd(1:3);        % desired position
        P.pPos.Xd(7:9) = LF.pPos.dXr(1:3);       % desired velocities       
        % Drone
        A.pPos.Xd(1:3) = LF.pPos.Xd(4:6);
        A.pPos.Xd(7:9) = LF.pPos.dXr(4:6);
        
        % Dynamic Controllers ................................................
        A = cUnderActuatedControllerMexido(A,gains); % ArDrone
        A = J.mControl(A);                           % joystick command (priority)
        P = fDynamicController(P);                   % Pioneer Dynamic controller

        %% Save data (.txt file)
        fprintf(Arq,'%6.6f\t',[P.pPos.Xd' P.pPos.X' P.pSC.Ud(1:2)' P.pSC.U(1:2)' ...
            A.pPos.Xd' A.pPos.X' A.pSC.Ud' A.pSC.U' LF.pPos.Qd' LF.pPos.Q' toc(t)]);
        fprintf(Arq,'\n\r');
   
        %% Send control signals to robots
        Rede.mSendMsg(P);       % send data to network
        A.rSendControlSignals;  % Send command to ardrone
        
    end  
end

%% Loop Aterrissagem
tsim = toc(t);
tland = 5;
while toc(t) < tsim+tland     
    if toc(tc) > 1/30
        tc = tic;
        %% Trajectory
        % Lemniscata (8')
        ta = toc(t);
        % Positions
        LF.pPos.Qd(1)  = LF.pPos.Q(1);         % x position
        LF.pPos.Qd(2)  = LF.pPos.Q(2);         % y position
        % LF.pPos.Qd(3)  = 0;                   % z position
        LF.pPos.Qd(4)  = Qd(end,4) - (Qd(end,4)-0.5)*(ta-tsim)/(tland);                   % rho position
        %         LF.pPos.Qd(5)  = deg2rad(0);          % alpha position
        %         LF.pPos.Qd(6)  = deg2rad(90);         % beta position
        % Velocities
        LF.pPos.dQd(1)  = 0;                  % x velocities
        LF.pPos.dQd(2)  = 0;                  % y velocities
        LF.pPos.dQd(3)  = 0;                  % z velocities
        LF.pPos.dQd(4)  = 0;                  % rho velocities
        LF.pPos.dQd(5)  = 0;                  % alpha velocities
        LF.pPos.dQd(6)  = 0;                  % beta velocities
        
        %% Acquire sensors data
        % Get network data
        Rede.mReceiveMsg;
        if length(Rede.pMSG.getFrom)>1
            P.pSC.U  = Rede.pMSG.getFrom{2}(29:30);  % current velocities (robot sensors)
            PX       = Rede.pMSG.getFrom{2}(14+(1:12));   % current position (robot sensors)
        end
        
        % Get optitrack data
        rb = OPT.RigidBody;             % read optitrack
        % Ardrone
        A = getOptData(rb(idA),A);
        A.pSC.U = [A.pPos.X(4);A.pPos.X(5);A.pPos.X(9);A.pPos.X(12)]; % populates actual control signal to save data
        P = getOptData(rb(idP),P);
        
        %% Control
        % Formation Members Position
        LF.pPos.X = [P.pPos.X(1:3); A.pPos.X(1:3)];

        % Formation Controller
        LF.mFormationControl;
        
        % Desired position ...........................................
        LF.mInvTrans;
        % Pioneer
        P.pPos.Xd(1:3) = LF.pPos.Xd(1:3);        % desired position 
        P.pPos.Xd(7:9) = LF.pPos.dXr(1:3);       % desired velocities
       
        
        % Drone
        A.pPos.Xda     = A.pPos.Xd;              % save previous posture
        A.pPos.Xd(1:3) = LF.pPos.Xd(4:6);    % desired position
        A.pPos.Xd(7:9) = LF.pPos.dXr(4:6);   % desired velocities
        A.pPos.Xd(6)   = 0; %P.pPos.X(6); % atan2(A.pPos.Xd(8),A.pPos.Xd(7)); % desired Psi
        
        % Derivative (dPsi)
%         if abs(A.pPos.Xd(6) - A.pPos.Xda(6)) > pi
%             if A.pPos.Xda(6) < 0
%                 A.pPos.Xda(6) =  2*pi + A.pPos.Xda(6);
%             else
%                 A.pPos.Xda(6) = -2*pi + A.pPos.Xda(6);
%             end
%         end
        A.pPos.Xd(12) = 0; %(A.pPos.Xd(6) - A.pPos.Xda(6))/(1/30);
        
        % ............................................................
        % Dynamic controllers
        A = cUnderActuatedController(A,gains);  % ArDrone
        A = J.mControl(A);                      % joystick command (priority)
        P = fDynamicController(P);              % Pioneer Dynamic controller
        
        %% Save data (.txt file)
        fprintf(Arq,'%6.6f\t',[P.pPos.Xd' P.pPos.X' P.pSC.Ud(1:2)' P.pSC.U(1:2)' ...
            A.pPos.Xd' A.pPos.X' A.pSC.Ud' A.pSC.U' LF.pPos.Qd' LF.pPos.Q' toc(t)]);
        fprintf(Arq,'\n\r');

        %% Send control signals to robots        
        P.pSC.Ud = [0; 0]; % stop Pioneer
        Rede.mSendMsg(P);  % send data to network        
        A.rSendControlSignals;
    end

end

%% Close files
fclose(Arq);
%%  Stop robot
% Send to network (a few times to be sure)
P.pSC.Ud = [0;0];
for ii = 1:5
    Rede.mSendMsg(P);
end
% Land drone
if A.pFlag.Connected == 1
    A.rLand;
end

% End of code xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
