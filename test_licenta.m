[fname, fpath] = uigetfile({'*.jpg;*.png;*.jpeg;*.bmp;*.tiff;*.gif'}, 'Select the plant image for analysis');

if isequal(fname,0) || isequal(fpath,0)
    disp('Selection cancelled.');
    return;
end

I = imread(strcat(fpath,fname));
fprintf('Processing image: %s\n', fname);

rng(42); % fixeaza generatorul de numere aleatoare pentru rezultate reproductibile

figure(1); imshow(I); title('Original Image');

%% Step 0: Remove background (white wall / pot) using saturation
hsv_full = rgb2hsv(I);
S_full = hsv_full(:,:,2);
V_full = hsv_full(:,:,3);

plant_mask = (S_full >= 0.30) & (V_full >= 0.10);

R_all = double(I(:,:,1));
G_all = double(I(:,:,2));
B_all = double(I(:,:,3));

R = R_all(plant_mask);
G = G_all(plant_mask);
B = B_all(plant_mask);

fprintf('Plant pixels kept after background removal: %d / %d\n', length(R), numel(plant_mask));

%% Step 1: Choose number of clusters and pick random initial centroids
NC = 6; % more clusters = finer color resolution, less risk of small
        % color groups (like dried brown tips) being absorbed by larger ones

V = R*256^2 + G*256 + B;
culori = sort(V);
culori = culori(diff(culori) > 0);
fprintf('Distinct colors found: %d\n', length(culori));

poz = randperm(length(culori), NC);
VC = culori(poz);

RC = floor(VC/256^2);          VC = VC - RC*256^2;
GC = floor(VC/256);            VC = VC - GC*256;
BC = VC;

C = zeros(length(R),1);
iter = 0;

while true
    %% Step 2: Distance from every pixel to every centroid
    dist = zeros(length(R), NC);
    for k = 1:NC
        dist(:,k) = sqrt((R-RC(k)).^2 + (G-GC(k)).^2 + (B-BC(k)).^2);
    end

    %% Step 3: Assign each pixel to the closest centroid
    [~, idx] = min(dist, [], 2);
    C = idx;

    %% Step 4: Recompute centroids as the mean color of each cluster
    new_RC = zeros(NC,1); new_GC = zeros(NC,1); new_BC = zeros(NC,1);
    for k = 1:NC
        len = sum(C==k);
        if len == 0
            new_RC(k) = RC(k); new_GC(k) = GC(k); new_BC(k) = BC(k);
            continue;
        end
        new_RC(k) = round(sum((C==k).*R)/len);
        new_GC(k) = round(sum((C==k).*G)/len);
        new_BC(k) = round(sum((C==k).*B)/len);
    end

    iter = iter+1;

    %% Step 5: Stop when centroids stabilize
    dif = sum(abs(new_RC-RC)) + sum(abs(new_GC-GC)) + sum(abs(new_BC-BC));
    fprintf('Iter: %d, centroid difference: %d\n', iter, dif);

    RC = new_RC; GC = new_GC; BC = new_BC;

    if dif < NC || iter > 50
        break;
    end
end

% Visualize the segmented plant pixels (background shown as black)
lin = size(I,1); col = size(I,2);
new_I = zeros(lin, col, 3, 'uint8');
full_C = zeros(lin*col,1);
full_C(plant_mask) = C;
full_C = reshape(full_C, lin, col);

for k = 1:NC
    mask_k = (full_C == k);
    new_I(:,:,1) = new_I(:,:,1) + uint8(mask_k)*uint8(RC(k));
    new_I(:,:,2) = new_I(:,:,2) + uint8(mask_k)*uint8(GC(k));
    new_I(:,:,3) = new_I(:,:,3) + uint8(mask_k)*uint8(BC(k));
end

figure(2); imshow(new_I); title(sprintf('K-means Segmentation (background removed, %d clusters)', NC));

%% Step 6: Group the NC clusters into green / yellow / brown
% based on each centroid's hue and brightness in HSV space
hsv_centroids = rgb2hsv([RC GC BC]/255);
hues = hsv_centroids(:,1);
sats = hsv_centroids(:,2);
vals = hsv_centroids(:,3);

label = cell(NC,1);

fprintf('\nCentroid colors found (RGB -> HSV):\n');
for k = 1:NC
    h = hues(k); s = sats(k); v = vals(k);
    fprintf('Cluster %d: R=%d G=%d B=%d -> H=%.2f S=%.2f V=%.2f\n', k, RC(k), GC(k), BC(k), h, s, v);
    if h >= 0.16
        label{k} = 'green';
    elseif h >= 0.13 && h < 0.16
        label{k} = 'yellow';
    elseif h >= 0.02 && h < 0.13
        label{k} = 'brown';
    else
        label{k} = 'other';
    end
end

pixels_green  = 0; pixels_yellow = 0; pixels_brown = 0;
for k = 1:NC
    count_k = sum(C==k);
    switch label{k}
        case 'green',  pixels_green  = pixels_green  + count_k;
        case 'yellow', pixels_yellow = pixels_yellow + count_k;
        case 'brown',  pixels_brown  = pixels_brown  + count_k;
    end
end

fprintf('\nCluster labels: ');
fprintf('%s ', label{:});
fprintf('\n');

total_plant_pixels = pixels_green + pixels_yellow + pixels_brown;

if total_plant_pixels == 0
    fprintf('\n[WARNING] No cluster matched plant colors. Try a different image or NC.\n');
    return;
end

percent_green  = (pixels_green  / total_plant_pixels) * 100;
percent_yellow = (pixels_yellow / total_plant_pixels) * 100;
percent_brown  = (pixels_brown  / total_plant_pixels) * 100;

fprintf('\n--- PLANT HEALTH ANALYSIS RESULTS (K-means) ---\n');
fprintf('GREEN:  %.2f%%\n', percent_green);
fprintf('YELLOW: %.2f%%\n', percent_yellow);
fprintf('BROWN:  %.2f%%\n', percent_brown);
fprintf('------------------------------------------------\n');

%% Step 7: Overall status based on proportion of healthy tissue
if percent_green >= 60
    status = 'Healthy';
elseif percent_green >= 35
    status = 'Warning';
else
    status = 'Critical';
end

plantData.percentGreen  = percent_green;
plantData.percentYellow = percent_yellow;
plantData.percentBrown  = percent_brown;
plantData.status        = status;

%% Step 8: Send results to Node-RED over HTTP
url = 'http://172.20.10.2:1880/plant-health';
options = weboptions('MediaType', 'application/json', 'Timeout', 10);

try
    webwrite(url, plantData, options);
    fprintf('\n[OK] Data sent to Node-RED successfully.\n');
    fprintf('Status: %s\n', status);
catch ME
    fprintf('\n[ERROR] Failed to send data to Node-RED: %s\n', ME.message);
end