// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.9.0;
pragma experimental ABIEncoderV2;

contract OMS_COVID{

    //Direccion de la OMS -> Owner / dueño del contrato
    address public OMS;

    constructor() public {
        OMS = msg.sender;
    }

    //Relacion los centros de salud (direccion/addres) con la validez del sistema de gestion
    //Cada wallet puede ser un sistema de salud
    mapping(address => bool) public Validacion_CentrosSalud;

    //Relacionar una direccion de un centro de salud con su contrato
    mapping (address => address) public CentroSalud_Contrato;

    //Ej: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 -> true == Tiene permisos para crear su smart contract
    //0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 -> false == NO tiene permisos para crear su smart contract

    //Array de direcciones que almacene los contratos de los centros de salud validados
    address [] public direcciones_contratos_salud;

    //Array de las direccion que soliciten acceso
    address [] Solicitudes;

    event SolicitudAcceso(address);
    event NuevoCentroValidado(address);
    event NuevoContrato(address, address);


    modifier UnicamenteOMS(address _direccion){
        require(_direccion == OMS, "No tienes permisos para realizar esta funcion");
        _;
    }

    //Funcion para solicitar acceso al sistema medico
    function SolicitarAcceso() public {
        Solicitudes.push(msg.sender);
        emit SolicitudAcceso(msg.sender);
    }

    //Funcion que visualiza las direcciones que han solicitado este acceso
    function VisualizarSolicitudes() public view UnicamenteOMS(msg.sender) returns (address [] memory){
        return Solicitudes;
    }

    //Funcion para validar nuevos centros de saludos que puedan autogestionarse
    function CentrosSalud(address _centroSalud) public UnicamenteOMS(msg.sender){
        Validacion_CentrosSalud[_centroSalud] = true;
        emit NuevoCentroValidado(_centroSalud);
    }

    //Funcion que permita crear un contrato inteligente de un centro de salud
    function FactoryCentroSalud() public {
        //Filtrado para que unicamente los centros de salud validados sean capaces de ejecutar esta funcion
        require(Validacion_CentrosSalud[msg.sender] == true, "No tienes permisos para realizar esta funcion.");
        //Generar un smart contract -> Generar su direccion
        address contrato_CentroSalud = address (new CentroSalud(msg.sender));
        //Alamacenamiento la direccion del contrato en el array
        direcciones_contratos_salud.push(contrato_CentroSalud);
        //Relacion entre el centro de salud y su contrato
        CentroSalud_Contrato[msg.sender] = contrato_CentroSalud;
        emit NuevoContrato(contrato_CentroSalud, msg.sender);
    }
}

//Contrato autogestionable por el centro de salud
contract CentroSalud{

    //Direcciones iniciales
    address public DireccionCentroSalud;
    address public DireccionContrato;

    constructor (address _direccion) public {
        DireccionCentroSalud = _direccion;
        DireccionContrato = address(this);
    }

    //Mapping para relacionar el hash de la persona con los resultados (Diagnostico, CODIGO IPFS)
    mapping(bytes32 => Resultados) ResultadosCOVID;

    //Esctructura de los resultados
    struct Resultados{
        bool diagnostico;
        string CodigoIPFS;
    }

    event NuevoResultado(string, bool);

    //Filtrar las funciones a ejecutar por el centro de salud
    modifier UnicamenteCentroSalud(address _direccion){
        require(_direccion == DireccionCentroSalud, "No tienes permisos para ejecutar esta funcion.");
        _;
    }

    //Funcion para emitir un resultado de una prueba de COVID
    // ID = 1234X , RESULTADO = true, CODIGO = QmUHTz2g89YMnw6pJueVi31ZLdUeV4M4mPKgRE96mfhaen (Para identificar al PDF de esta prueba)
    function ResultadosPruebaCovid(string memory _idPersona, bool _resultadoCOVID, string memory _codigoIPFS) public UnicamenteCentroSalud(msg.sender){
        //Hash de la identificacion de la persona
        bytes32 hash_idPersona = keccak256(abi.encodePacked(_idPersona));

        //Relacion del hash de la persona con la estructura de los resultados
        ResultadosCOVID[hash_idPersona] = Resultados(_resultadoCOVID, _codigoIPFS);

        emit NuevoResultado(_codigoIPFS, _resultadoCOVID);
    }

    //Funcion que permita la visualizacion de los resultados
    function VisualizarResultados(string memory _idPersona) public view returns(string memory _resultadoPrueba, string memory _codigoIPFS){
        //Hash de la identidad de la persona
        bytes32 hash_idPersona = keccak256(abi.encodePacked(_idPersona));
        string memory resultadoPrueba;

        if(ResultadosCOVID[hash_idPersona].diagnostico == true){
            resultadoPrueba = "Positivo";
        }else{
            resultadoPrueba = "No detectable";
        }

        //Evito el return
        _resultadoPrueba = resultadoPrueba;
        _codigoIPFS = ResultadosCOVID[hash_idPersona].CodigoIPFS;
    }
        
}