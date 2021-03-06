function Path = cPathFollowingReference(Name)
if nargin < 1
    Name = 'HypPar';
end

switch Name
    case 'HypPar'
        % This path is a circle in xy plane and an 8-shape in xz plane
        % Hyperbolic Paraboloid
        t = 0:pi/180:2*pi;
        a = 1;
        b = 1;
        c = 0.5;
        
        Path(1:3,:)   = [a*cos(t)+0.01; b*sin(t); c*sin(2*t)+1];
        Path(7:9,:)   = [-a*sin(t); b*cos(t); 2*c*cos(0.1*t)];
        Path(4:5,:)   = zeros(2,length(t));
        Path(6,:)     = atan2(Path(8,:),Path(7,:));
        Path(10:11,:) = zeros(2,length(t));
        Path(12,:)    = 0; %(a*b)./(a^2*sin(t).^2 + b^2*cos(t).^2);
        
    case 'Lemniscata'
        % An 8-shape path with fixed heigh
        
        t = 0:pi/180:2*pi;
        a = 1.2;
        b = 1;
        c = 1;
        
        Path(1:3,:)   = [a*sin(t);b*sin(2*t); c*ones(length(t))];
        Path(7:9,:)   = [a*cos(t); 2*b*cos(t); 0];
        Path(4:5,:)   = zeros(2,length(t));
        Path(6,:)     = atan2(Path(8,:),Path(7,:));
        Path(10:11,:) = zeros(2,length(t));
        Path(12,:)    = 0;
        
    case 'Lemniscata2'
        % An 8-shape path inclined (Y axis rotation)
        t = 0:pi/180:2*pi;
        a = 1.2;
        b = 1;
        c = 0.25;
        
        Path(1:3,:)   = [a*sin(t);b*sin(2*t); 1.25 + c*sin(t)];
        Path(7:9,:)   = [a*cos(t); 2*b*cos(t); c*cos(t)];
        Path(4:5,:)   = zeros(2,length(t));
        Path(6,:)     = atan2(Path(8,:),Path(7,:));
        Path(10:11,:) = zeros(2,length(t));
        Path(12,:)    = 0;
        
    case 'Lemniscata3'
        % An 8-shaped path with its center shifted upwards
        t = 0:pi/180:2*pi;
        a = 1.2;
        b = 1;
        c = 0.25;
        
        Path(1:3,:)   = [a*sin(t);b*sin(2*t); 1.25 + c*cos(2*t)];
        Path(7:9,:)   = [a*cos(t); 2*b*cos(t); -2*c*sin(2*t)];
        Path(4:5,:)   = zeros(2,length(t));
        Path(6,:)     = atan2(Path(8,:),Path(7,:));
        Path(10:11,:) = zeros(2,length(t));
        Path(12,:)    = 0;
        
        
        
end